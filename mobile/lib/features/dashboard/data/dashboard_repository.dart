import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/dashboard_data.dart';

export '../domain/dashboard_data.dart';

class DashboardRepository extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  Future<void> load() async {
    final session = _ref.read(sessionProvider);
    if (!session.isLoggedIn) {
      if (!mounted) return;
      state = const AsyncValue.loading();
      return;
    }

    final companyId = _companyId ?? 'default';

    // 1. Immediately calculate from authoritative local SQLite — scoped to this company
    DashboardData? local;
    try {
      local = await LocalFinancialCalculator.calculateDashboard(
        companyId: companyId,
      );
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {
      local = DashboardData.empty;
      if (!mounted) return;
      state = AsyncValue.data(local);
    }

    // 2. Fetch authoritative dashboard from API in the background if online, and reconcile with unsynced local transactions
    final status = _ref.read(connectionStatusProvider);
    if (status != ConnectionStatus.online) {
      // While offline, SQLite is the ground truth
      return;
    }

    try {
      final client = _ref.read(apiClientProvider);
      dynamic response;
      try {
        response = await client.get('/dashboard');
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          try {
            response = await client.get('/analytics/dashboard');
          } on ApiException catch (e2) {
            if (e2.statusCode == 404) {
              response = await client.get('/analytics');
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      final rawData = response['data'] ?? response;
      final data = rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{});
      final serverData = DashboardData.fromJson(data);

      // Reconcile with local unsynchronized transactions (synced = 0) so pending/failed local mutations are preserved without double-counting
      final db = await AppDatabase.instance.database;
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final unsyncedSalesRes = await db.rawQuery(
        '''
        SELECT
          COALESCE(SUM(total), 0) AS revenue,
          COALESCE(SUM(
            (SELECT COALESCE(SUM(si.unit_cost * si.quantity), 0) FROM sale_items si WHERE si.sale_id = s.id)
          ), 0) AS cogs,
          COUNT(*) AS sales_count
        FROM sales s
        WHERE s.company_id = ? AND s.synced = 0 AND date(s.sold_at) = date(?)
        ''',
        [companyId, todayStr],
      );
      final unsyncedExpRes = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS expenses
        FROM expenses
        WHERE company_id = ? AND synced = 0 AND date(expense_date) = date(?)
        ''',
        [companyId, todayStr],
      );

      final unsyncedRevenue = (unsyncedSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
      final unsyncedCogs = (unsyncedSalesRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
      final unsyncedSalesCount = (unsyncedSalesRes.first['sales_count'] as num?)?.toInt() ?? 0;
      final unsyncedExpenses = (unsyncedExpRes.first['expenses'] as num?)?.toDouble() ?? 0.0;
      final unsyncedGrossProfit = unsyncedRevenue - unsyncedCogs;
      final unsyncedNetProfit = unsyncedGrossProfit - unsyncedExpenses;

      final reconciled = DashboardData(
        todayRevenue: serverData.todayRevenue + unsyncedRevenue,
        todayExpenses: serverData.todayExpenses + unsyncedExpenses,
        todayProfit: serverData.todayProfit + unsyncedNetProfit,
        todayGrossProfit: serverData.todayGrossProfit != null
            ? (serverData.todayGrossProfit! + unsyncedGrossProfit)
            : null,
        salesCount: serverData.salesCount + unsyncedSalesCount,
        lowStockCount: local.lowStockCount,
        unpaidInvoicesCount: local.unpaidInvoicesCount,
        upcomingAppointmentsCount: serverData.upcomingAppointmentsCount,
        totalOutstandingCredit: serverData.totalOutstandingCredit,
        inventoryValue: local.inventoryValue,
      );

      state = AsyncValue.data(reconciled);
    } catch (_) {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current != null) {
        return; // Keep local calculated or empty dashboard numbers
      }
      state = AsyncValue.data(local);
    }
  }
}

final dashboardRepositoryProvider =
    StateNotifierProvider<DashboardRepository, AsyncValue<DashboardData>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return DashboardRepository(ref);
  },
);

import 'dart:math' as math;
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
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Immediately calculate from authoritative local SQLite — scoped to this company
    DashboardData? local;
    try {
      local = await LocalFinancialCalculator.calculateDashboard(
        companyId: companyId,
        date: todayStr,
      );
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (e) {
      // Diagnostic logging (error category and company, no secrets)
      // ignore: avoid_print
      print('[DASHBOARD] Local calculation error for tenant=$companyId date=$todayStr: $e');
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
        response = await client.get('/dashboard', query: {'date': todayStr});
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          try {
            response = await client.get('/analytics/dashboard', query: {'date': todayStr});
          } on ApiException catch (e2) {
            if (e2.statusCode == 404) {
              response = await client.get('/analytics', query: {'date': todayStr});
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
      final unsyncedSalesRes = await db.rawQuery(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN s.payment_status = 'paid' THEN s.total ELSE 0 END), 0) AS revenue,
          COALESCE(SUM(
            (SELECT COALESCE(SUM(COALESCE(NULLIF(si.unit_cost, 0), p.purchase_price, 0) * si.quantity), 0)
             FROM sale_items si
             LEFT JOIN products p ON p.id = si.product_id AND (p.company_id = s.company_id OR p.company_id IS NULL)
             WHERE si.sale_id = s.id)
          ), 0) AS cogs,
          COUNT(*) AS sales_count
        FROM sales s
        WHERE s.company_id = ? AND s.synced = 0 AND s.payment_status != 'cancelled' AND ${LocalFinancialCalculator.safeSSoldAtDate} = date(?)
        ''',
        [companyId, todayStr],
      );
      final unsyncedExpRes = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS expenses
        FROM expenses
        WHERE company_id = ? AND synced = 0 AND ${LocalFinancialCalculator.safeExpenseDate} = date(?)
        ''',
        [companyId, todayStr],
      );

      double unsyncedCredit = 0.0;
      try {
        final unsyncedCreditRes = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(amount), 0) AS total
          FROM credit_payments
          WHERE company_id = ? AND synced = 0
            AND ${LocalFinancialCalculator.safeCreatedAtDate} = date(?)
          ''',
          [companyId, todayStr],
        );
        unsyncedCredit = (unsyncedCreditRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}

      final unsyncedSalesRevenue = (unsyncedSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
      final unsyncedRevenue = unsyncedSalesRevenue + unsyncedCredit;
      final unsyncedCogs = (unsyncedSalesRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
      final unsyncedSalesCount = (unsyncedSalesRes.first['sales_count'] as num?)?.toInt() ?? 0;
      final unsyncedExpenses = (unsyncedExpRes.first['expenses'] as num?)?.toDouble() ?? 0.0;
      final unsyncedGrossProfit = unsyncedRevenue - unsyncedCogs;
      final unsyncedNetProfit = unsyncedGrossProfit - unsyncedExpenses;

      final combinedRevenue = serverData.todayRevenue + unsyncedRevenue;
      final finalRevenue = math.max(local.todayRevenue, combinedRevenue);
      final finalSalesCount = math.max(local.salesCount, serverData.salesCount + unsyncedSalesCount);
      final finalExpenses = math.max(local.todayExpenses, serverData.todayExpenses + unsyncedExpenses);
      final finalProfit = combinedRevenue >= local.todayRevenue
          ? (serverData.todayProfit + unsyncedNetProfit)
          : local.todayProfit;
      final finalGrossProfit = (combinedRevenue >= local.todayRevenue && serverData.todayGrossProfit != null)
          ? (serverData.todayGrossProfit! + unsyncedGrossProfit)
          : local.todayGrossProfit;

      final reconciled = DashboardData(
        todayRevenue: finalRevenue,
        todayExpenses: finalExpenses,
        todayProfit: finalProfit,
        todayGrossProfit: finalGrossProfit,
        salesCount: finalSalesCount,
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
    ref.watch(sessionProvider.select((s) => s.companyId ?? s.userId));
    ref.watch(connectionStatusProvider);
    return DashboardRepository(ref);
  },
);

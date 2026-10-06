import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/superette_models.dart';

class SuperetteRepository {
  SuperetteRepository(this._ref);
  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<SuperetteDashboardStats> dashboard() async {
    final companyId = _companyId;
    if (companyId == null) {
      return SuperetteDashboardStats(
        todayRevenue: 0, todayGrossProfit: 0, todayNetProfit: 0, todayExpenses: 0,
        transactionsToday: 0, productsSoldToday: 0, weekRevenue: 0, monthRevenue: 0,
        lowStockCount: 0, lowStockProducts: [], stockCostValue: 0, stockRetailValue: 0,
        unitsInStock: 0, bestSellingProducts: [], suppliersCount: 0,
        customersCount: 0, outstandingDebt: 0, debtorsCount: 0, topDebtors: [],
      );
    }

    // 1. Calculate from local SQLite first (instant & offline) — scoped to company
    SuperetteDashboardStats? localStats;
    try {
      localStats = await LocalFinancialCalculator.calculateSuperetteDashboard(
        companyId: companyId,
      );
    } catch (_) {}

    final status = _ref.read(connectionStatusProvider);
    final syncState = _ref.read(syncServiceProvider);
    if (status != ConnectionStatus.online || syncState.pendingCount > 0) {
      if (localStats != null) return localStats;
    }

    // 2. Fetch from server if online and no pending mutations
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/superette/dashboard');
      return SuperetteDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
    } catch (_) {
      if (localStats != null) return localStats;
      rethrow;
    }
  }
}

final superetteRepositoryProvider = Provider<SuperetteRepository>((ref) => SuperetteRepository(ref));

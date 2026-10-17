import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/superette_models.dart';

class SuperetteRepository {
  SuperetteRepository(this._ref);
  final Ref _ref;

  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

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
    final defaultStats = SuperetteDashboardStats(
      todayRevenue: 0, todayGrossProfit: 0, todayNetProfit: 0, todayExpenses: 0,
      transactionsToday: 0, productsSoldToday: 0, weekRevenue: 0, monthRevenue: 0,
      lowStockCount: 0, lowStockProducts: [], stockCostValue: 0, stockRetailValue: 0,
      unitsInStock: 0, bestSellingProducts: [], suppliersCount: 0,
      customersCount: 0, outstandingDebt: 0, debtorsCount: 0, topDebtors: [],
    );

    if (status != ConnectionStatus.online || syncState.pendingCount > 0) {
      return localStats ?? defaultStats;
    }

    // 2. Fetch from server if online and no pending mutations
    try {
      final client = _ref.read(apiClientProvider);
      dynamic response;
      try {
        response = await client.get('/superette/dashboard');
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          response = await client.get('/analytics/dashboard');
        } else {
          rethrow;
        }
      }
      final raw = response['data'] ?? response;
      final data = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
      final serverStats = SuperetteDashboardStats.fromJson(data);
      if (localStats != null && localStats.todayRevenue > serverStats.todayRevenue) {
        return SuperetteDashboardStats(
          todayRevenue: localStats.todayRevenue,
          todayGrossProfit: localStats.todayGrossProfit,
          todayNetProfit: localStats.todayNetProfit,
          todayExpenses: math.max(localStats.todayExpenses, serverStats.todayExpenses),
          transactionsToday: math.max(localStats.transactionsToday, serverStats.transactionsToday),
          productsSoldToday: math.max(localStats.productsSoldToday, serverStats.productsSoldToday),
          weekRevenue: math.max(localStats.weekRevenue, serverStats.weekRevenue),
          monthRevenue: math.max(localStats.monthRevenue, serverStats.monthRevenue),
          lowStockCount: serverStats.lowStockCount,
          lowStockProducts: serverStats.lowStockProducts.isNotEmpty ? serverStats.lowStockProducts : localStats.lowStockProducts,
          stockCostValue: localStats.stockCostValue,
          stockRetailValue: localStats.stockRetailValue,
          unitsInStock: localStats.unitsInStock,
          bestSellingProducts: serverStats.bestSellingProducts.isNotEmpty ? serverStats.bestSellingProducts : localStats.bestSellingProducts,
          suppliersCount: math.max(localStats.suppliersCount, serverStats.suppliersCount),
          customersCount: math.max(localStats.customersCount, serverStats.customersCount),
          outstandingDebt: serverStats.outstandingDebt,
          debtorsCount: serverStats.debtorsCount,
          topDebtors: serverStats.topDebtors,
        );
      }
      return serverStats;
    } catch (_) {
      return localStats ?? defaultStats;
    }
  }
}

final superetteRepositoryProvider = Provider<SuperetteRepository>((ref) => SuperetteRepository(ref));

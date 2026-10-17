import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/clothing_models.dart';

class ClothingRepository {
  ClothingRepository(this._ref);
  final Ref _ref;

  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  Future<ClothingDashboardStats> dashboard() async {
    final companyId = _companyId;
    if (companyId == null) {
      return ClothingDashboardStats(
        todayRevenue: 0, todayGrossProfit: 0, todayNetProfit: 0, todayExpenses: 0,
        transactionsToday: 0, itemsSoldToday: 0, weekRevenue: 0, monthRevenue: 0,
        lowStockCount: 0, lowStockProducts: [], stockCostValue: 0, stockRetailValue: 0,
        unitsInStock: 0, bestSellingProducts: [], stockByCategory: [],
        suppliersCount: 0, customersCount: 0, outstandingDebt: 0, debtorsCount: 0, topDebtors: [],
      );
    }

    ClothingDashboardStats? localStats;
    try {
      localStats = await LocalFinancialCalculator.calculateClothingDashboard(companyId: companyId);
    } catch (_) {}

    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    final syncState = _ref.read(syncServiceProvider);
    if (isOnline && syncState.pendingCount == 0) {
      try {
        final client = _ref.read(apiClientProvider);
        final response = await client.get('/clothing/dashboard');
        final serverStats = ClothingDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
        if (localStats != null && localStats.todayRevenue > serverStats.todayRevenue) {
          return ClothingDashboardStats(
            todayRevenue: localStats.todayRevenue,
            todayGrossProfit: localStats.todayGrossProfit,
            todayNetProfit: localStats.todayNetProfit,
            todayExpenses: math.max(localStats.todayExpenses, serverStats.todayExpenses),
            transactionsToday: math.max(localStats.transactionsToday, serverStats.transactionsToday),
            itemsSoldToday: math.max(localStats.itemsSoldToday, serverStats.itemsSoldToday),
            weekRevenue: math.max(localStats.weekRevenue, serverStats.weekRevenue),
            monthRevenue: math.max(localStats.monthRevenue, serverStats.monthRevenue),
            lowStockCount: serverStats.lowStockCount,
            lowStockProducts: serverStats.lowStockProducts.isNotEmpty ? serverStats.lowStockProducts : localStats.lowStockProducts,
            stockCostValue: localStats.stockCostValue,
            stockRetailValue: localStats.stockRetailValue,
            unitsInStock: localStats.unitsInStock,
            bestSellingProducts: serverStats.bestSellingProducts.isNotEmpty ? serverStats.bestSellingProducts : localStats.bestSellingProducts,
            stockByCategory: serverStats.stockByCategory.isNotEmpty ? serverStats.stockByCategory : localStats.stockByCategory,
            suppliersCount: math.max(localStats.suppliersCount, serverStats.suppliersCount),
            customersCount: math.max(localStats.customersCount, serverStats.customersCount),
            outstandingDebt: serverStats.outstandingDebt,
            debtorsCount: serverStats.debtorsCount,
            topDebtors: serverStats.topDebtors,
          );
        }
        return serverStats;
      } catch (_) {}
    }

    // Offline fallback — scoped to the active company
    return localStats ?? await LocalFinancialCalculator.calculateClothingDashboard(companyId: companyId);
  }
}

final clothingRepositoryProvider = Provider<ClothingRepository>((ref) => ClothingRepository(ref));

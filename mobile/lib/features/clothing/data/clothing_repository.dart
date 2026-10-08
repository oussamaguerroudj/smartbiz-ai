import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../domain/clothing_models.dart';

class ClothingRepository {
  ClothingRepository(this._ref);
  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

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

    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (isOnline) {
      try {
        final client = _ref.read(apiClientProvider);
        final response = await client.get('/clothing/dashboard');
        return ClothingDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
      } catch (_) {}
    }

    // Offline fallback — scoped to the active company
    return LocalFinancialCalculator.calculateClothingDashboard(companyId: companyId);
  }
}

final clothingRepositoryProvider = Provider<ClothingRepository>((ref) => ClothingRepository(ref));

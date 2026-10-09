import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/pharmacy_models.dart';

class PharmacyRepository {
  PharmacyRepository(this._ref);
  final Ref _ref;

  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  Future<PharmacyDashboardStats> dashboard() async {
    final companyId = _companyId;
    if (companyId == null) {
      return PharmacyDashboardStats(
        todayRevenue: 0, todayGrossProfit: 0, todayNetProfit: 0, todayExpenses: 0,
        transactionsToday: 0, productsSoldToday: 0, weekRevenue: 0, monthRevenue: 0,
        lowStockCount: 0, lowStockProducts: [], expiringCount: 0, expiringProducts: [],
        expiredCount: 0, inventoryCostValue: 0, inventoryRetailValue: 0,
        unitsInStock: 0, bestSellingProducts: [], suppliersCount: 0,
      );
    }

    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    final syncState = _ref.read(syncServiceProvider);
    if (isOnline && syncState.pendingCount == 0) {
      try {
        final client = _ref.read(apiClientProvider);
        final response = await client.get('/pharmacy/dashboard');
        return PharmacyDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
      } catch (_) {}
    }

    // Offline fallback — scoped to the active company
    return LocalFinancialCalculator.calculatePharmacyDashboard(companyId: companyId);
  }

  Future<List<PharmacyExpiringProduct>> expiringProducts({int days = 30}) async {
    final companyId = _companyId;
    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (isOnline) {
      try {
        final client = _ref.read(apiClientProvider);
        final response = await client.get('/pharmacy/expiring-products', query: {'days': '$days'});
        final rows = (response['data'] as List).cast<Map<String, dynamic>>();
        return rows.map(PharmacyExpiringProduct.fromJson).toList();
      } catch (_) {}
    }

    // Local calculation from SQLite — scoped to this company
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final targetDate = now.add(Duration(days: days));
    final todayStr = now.toIso8601String().substring(0, 10);
    final targetStr = targetDate.toIso8601String().substring(0, 10);

    final expiringRows = await db.rawQuery(
      '''SELECT id, name, expiration_date, quantity
         FROM products
         WHERE company_id = ?
           AND expiration_date IS NOT NULL
           AND date(expiration_date) BETWEEN date(?) AND date(?)
         ORDER BY expiration_date ASC''',
      [companyId, todayStr, targetStr],
    );

    return expiringRows.map((r) {
      final exp = DateTime.tryParse(r['expiration_date']?.toString() ?? '') ?? now;
      final diff = exp.difference(now).inDays;
      return PharmacyExpiringProduct(
        id: r['id'] as String,
        name: (r['name'] ?? 'Product') as String,
        expirationDate: exp,
        daysUntilExpiration: diff,
        quantity: (r['quantity'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) => PharmacyRepository(ref));

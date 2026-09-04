import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/sale.dart';
import '../../products/data/products_repository.dart';
import '../../invoices/data/invoices_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';

/// Real HTTP-backed Sales repository (Phase 5 wiring).
///
/// IMPORTANT SIMPLIFICATION vs. the Phase 4 local version: all the
/// "Validate products / Check stock / Update inventory / Calculate
/// profit / Generate invoice" logic that used to live in this file
/// (mirroring Spec Ch. 11 client-side) is now genuinely done server-side
/// inside a real PostgreSQL transaction with row locks (see backend
/// sales.service.js, verified working in Phase 5 testing — including
/// the oversell-rejection and ROLLBACK behavior). This repository's job
/// shrinks to: POST the cart, then refresh whichever other repositories
/// the sale just affected (stock changed → Products; a new invoice
/// exists → Invoices; today's KPIs changed → Dashboard).
class SalesRepository extends StateNotifier<AsyncValue<List<Sale>>> {
  SalesRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/sales');
      final sales = (response['data'] as List)
          .map((json) => Sale.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(sales);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Throws [ApiException] (e.g. code INSUFFICIENT_STOCK) if the server
  /// rejects the sale — nothing is refreshed in that case since nothing
  /// changed server-side either (transaction rolled back).
  Future<void> createSale({
    required List<SaleItemInput> items,
    double discount = 0,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    String? customerId,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/sales', body: {
      'items': items.map((i) => {'productId': i.productId, 'quantity': i.quantity}).toList(),
      'discount': discount,
      'paymentStatus': paymentStatusToApi(paymentStatus),
      if (customerId != null) 'customerId': customerId,
    });

    // Refresh everything this sale touched — keeps every screen honest
    // about real server state instead of guessing at optimistic deltas.
    await load();
    await _ref.read(productsRepositoryProvider.notifier).load();
    await _ref.read(invoicesRepositoryProvider.notifier).load();
    await _ref.read(dashboardRepositoryProvider.notifier).load();
  }
}

final salesRepositoryProvider = StateNotifierProvider<SalesRepository, AsyncValue<List<Sale>>>(
  (ref) => SalesRepository(ref),
);

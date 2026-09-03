import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/sale.dart';
import '../../products/data/products_repository.dart';

/// Local Sales repository. `createSale` reproduces the exact step
/// sequence from Spec Ch. 11.2:
///
///   Select product(s) → Enter quantity → Add to cart → Calculate total
///   → Confirm sale → Update inventory (auto) → Calculate profit (auto)
///   → Generate invoice
///
/// Steps 1–4 happen in the Create Sale screen's local cart state.
/// This method performs steps 5–8 atomically: it validates stock for
/// the WHOLE cart first (via ProductsRepository.validateStockAvailable),
/// and only if that fully succeeds does it decrement stock, record the
/// sale, and generate an invoice. If validation fails, nothing is
/// mutated — the local equivalent of the DB transaction + ROLLBACK
/// required by Spec (Ch. 11, "IMPORTANT: use Database Transaction").
/// The real ROLLBACK semantics land with the Postgres-backed API in
/// Phase 5; this is the client-side mirror of that same guarantee.
class SalesRepository extends StateNotifier<List<Sale>> {
  SalesRepository(this._ref) : super([]);

  final Ref _ref;
  int _saleCounter = 1042; // matches the spec's example sale numbering

  Sale createSale({
    required List<SaleItem> cartItems,
    required double discount,
    required PaymentStatus paymentStatus,
    String? customerName,
  }) {
    if (cartItems.isEmpty) {
      throw ArgumentError('Cannot create a sale with an empty cart');
    }

    final productsRepo = _ref.read(productsRepositoryProvider.notifier);

    // Step: Validate products / Check stock (whole cart, before any write)
    final requestedQuantities = <String, int>{};
    for (final item in cartItems) {
      requestedQuantities[item.productId] =
          (requestedQuantities[item.productId] ?? 0) + item.quantity;
    }
    productsRepo
        .validateStockAvailable(requestedQuantities); // throws on failure

    // Step: Update inventory (auto) — only reached if validation passed above
    productsRepo.decrementStock(requestedQuantities);

    // Step: Create Sale + Calculate profit (auto, via Sale getters)
    final sale = Sale(
      id: 's${_saleCounter++}',
      items: cartItems,
      discount: discount,
      paymentStatus: paymentStatus,
      soldAt: DateTime.now(),
      customerName: customerName,
    );
    state = [sale, ...state];

    // Step: Generate invoice
    final invoicesRepo = _ref.read(invoicesRepositoryProvider.notifier);
    invoicesRepo.createInvoiceForSale(sale);

    return sale;
  }
}

final salesRepositoryProvider =
    StateNotifierProvider<SalesRepository, List<Sale>>(
  (ref) => SalesRepository(ref),
);

/// Invoices repository — kept separate from Sales per the DB schema
/// (Phase 3: `invoices` is its own table, 1:1 with `sales`).
class InvoicesRepository extends StateNotifier<List<Invoice>> {
  InvoicesRepository() : super([]);

  int _invoiceCounter = 1042;

  Invoice createInvoiceForSale(Sale sale) {
    final invoice = Invoice(
      id: 'inv-${sale.id}',
      saleId: sale.id,
      invoiceNumber: 'INV-${_invoiceCounter++}',
      status: sale.paymentStatus == PaymentStatus.unpaid
          ? PaymentStatus.unpaid
          : PaymentStatus.paid,
    );
    state = [invoice, ...state];
    return invoice;
  }

  Invoice? forSale(String saleId) {
    for (final inv in state) {
      if (inv.saleId == saleId) return inv;
    }
    return null;
  }
}

final invoicesRepositoryProvider =
    StateNotifierProvider<InvoicesRepository, List<Invoice>>(
  (ref) => InvoicesRepository(),
);

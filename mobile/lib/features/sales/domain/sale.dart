// Sale / SaleItem / Invoice models — mirror `sales`, `sale_items`,
// `invoices` tables (Phase 3 migrations 007–008).

enum PaymentStatus { paid, unpaid, partial }

class SaleItem {
  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice, // snapshot of selling_price at time of sale
    required this.unitCost, // snapshot of purchase_price at time of sale
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double unitCost;

  double get lineTotal => unitPrice * quantity;
  double get lineProfit => (unitPrice - unitCost) * quantity;
}

class Sale {
  Sale({
    required this.id,
    required this.items,
    required this.discount,
    required this.paymentStatus,
    required this.soldAt,
    this.customerName,
  });

  final String id;
  final List<SaleItem> items;
  final double discount;
  final PaymentStatus paymentStatus;
  final DateTime soldAt;
  final String? customerName;

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  double get total => subtotal - discount;
  double get grossProfit => items.fold(0, (sum, i) => sum + i.lineProfit);
}

class Invoice {
  Invoice({
    required this.id,
    required this.saleId,
    required this.invoiceNumber,
    required this.status,
  });

  final String id;
  final String saleId;
  final String invoiceNumber;
  final PaymentStatus status;
}

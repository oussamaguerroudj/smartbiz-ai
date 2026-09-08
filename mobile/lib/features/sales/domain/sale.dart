/// Sale model — mirrors the `sales` list row shape returned by
/// GET /sales (sales.repository.js findAll, verified in Phase 5
/// testing, including the item_count subquery added for this batch).
enum PaymentStatus { paid, unpaid, partial }

PaymentStatus paymentStatusFromApi(String value) => switch (value) {
      'unpaid' => PaymentStatus.unpaid,
      'partial' => PaymentStatus.partial,
      _ => PaymentStatus.paid,
    };

String paymentStatusToApi(PaymentStatus status) => switch (status) {
      PaymentStatus.paid => 'paid',
      PaymentStatus.unpaid => 'unpaid',
      PaymentStatus.partial => 'partial',
    };

class Sale {
  Sale({
    required this.id,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentStatus,
    required this.soldAt,
    required this.itemCount,
    this.customerName,
    this.invoiceNumber,
  });

  final String id;
  final double subtotal;
  final double discount;
  final double total;
  final PaymentStatus paymentStatus;
  final DateTime soldAt;
  final int itemCount;
  final String? customerName;
  final String? invoiceNumber;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        subtotal: double.parse(json['subtotal'].toString()),
        discount: double.parse(json['discount'].toString()),
        total: double.parse(json['total'].toString()),
        paymentStatus: paymentStatusFromApi(json['payment_status'] as String),
        soldAt: DateTime.parse(json['sold_at'] as String),
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        customerName: json['customer_name'] as String?,
        invoiceNumber: json['invoice_number'] as String?,
      );
}

/// Input for creating a sale line item — only productId/quantity are
/// sent to the server; price/cost snapshots happen server-side (Phase 5
/// sales.service.js), never trusted from the client.
class SaleItemInput {
  SaleItemInput({required this.productId, required this.productName, required this.quantity});
  final String productId;
  final String productName; // display-only, for the cart UI
  final int quantity;
}

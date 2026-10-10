import '../../sales/domain/sale.dart';

/// Invoice model — two JSON shapes from the backend map here:
///  - list shape (GET /invoices): invoice + sale.total/sold_at + customer_name
///  - detail shape (GET /invoices/:id): same, plus subtotal/discount + items[]
/// Both are handled by making `items` optional (empty on the list shape).
class InvoiceLineItem {
  InvoiceLineItem({required this.productName, required this.quantity, required this.lineTotal});

  final String productName;
  final int quantity;
  final double lineTotal;

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) => InvoiceLineItem(
        productName: (json['product_name'] ?? json['productName'] ?? json['name'] ?? json['item_name'] ?? 'Product').toString(),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        lineTotal: double.tryParse((json['line_total'] ?? json['subtotal'] ?? json['total'] ?? 0).toString()) ?? 0.0,
      );
}

class Invoice {
  Invoice({
    required this.id,
    this.saleId,
    required this.invoiceNumber,
    required this.status,
    required this.total,
    required this.soldAt,
    this.customerName,
    this.items = const [],
  });

  final String id;
  final String? saleId;
  final String invoiceNumber;
  final PaymentStatus status;
  final double total;
  final DateTime soldAt;
  final String? customerName;
  final List<InvoiceLineItem> items;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as String,
        saleId: (json['sale_id'] ?? json['order_id']) as String?,
        invoiceNumber: json['invoice_number'] as String,
        status: paymentStatusFromApi(json['status'] as String),
        total: double.parse(json['total'].toString()),
        soldAt: DateTime.parse(json['sold_at'] as String),
        customerName: json['customer_name'] as String?,
        items: json['items'] != null
            ? (json['items'] as List)
                .map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
      );
}

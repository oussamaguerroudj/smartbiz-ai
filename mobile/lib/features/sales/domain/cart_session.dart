enum CartSessionStatus {
  active,
  onHold,
  checkout,
  completed,
  cancelled,
}

CartSessionStatus cartSessionStatusFromJson(String? raw) => switch (raw?.toUpperCase()) {
      'ON_HOLD' || 'ONHOLD' => CartSessionStatus.onHold,
      'CHECKOUT' => CartSessionStatus.checkout,
      'COMPLETED' => CartSessionStatus.completed,
      'CANCELLED' => CartSessionStatus.cancelled,
      _ => CartSessionStatus.active,
    };

String cartSessionStatusToJson(CartSessionStatus status) => switch (status) {
      CartSessionStatus.active => 'ACTIVE',
      CartSessionStatus.onHold => 'ON_HOLD',
      CartSessionStatus.checkout => 'CHECKOUT',
      CartSessionStatus.completed => 'COMPLETED',
      CartSessionStatus.cancelled => 'CANCELLED',
    };

class CartSessionItem {
  CartSessionItem({
    required this.id,
    required this.cartSessionId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.unitCost,
    this.quantity = 1,
  });

  final String id;
  final String cartSessionId;
  final String productId;
  final String productName;
  final double unitPrice;
  final double unitCost;
  int quantity;

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap(String companyId) => {
        'id': id,
        'cart_session_id': cartSessionId,
        'company_id': companyId,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'unit_cost': unitCost,
      };

  factory CartSessionItem.fromMap(Map<String, dynamic> map) => CartSessionItem(
        id: map['id'] as String,
        cartSessionId: map['cart_session_id'] as String,
        productId: map['product_id'] as String,
        productName: map['product_name'] as String,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      );

  CartSessionItem copyWith({
    String? id,
    String? cartSessionId,
    String? productId,
    String? productName,
    double? unitPrice,
    double? unitCost,
    int? quantity,
  }) =>
      CartSessionItem(
        id: id ?? this.id,
        cartSessionId: cartSessionId ?? this.cartSessionId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        unitPrice: unitPrice ?? this.unitPrice,
        unitCost: unitCost ?? this.unitCost,
        quantity: quantity ?? this.quantity,
      );
}

class CartSession {
  CartSession({
    required this.id,
    required this.companyId,
    this.customerId,
    this.customerName,
    this.status = CartSessionStatus.active,
    this.discount = 0.0,
    required this.createdAt,
    required this.updatedAt,
    List<CartSessionItem>? items,
  }) : items = items ?? [];

  final String id;
  final String companyId;
  String? customerId;
  String? customerName;
  CartSessionStatus status;
  double discount;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<CartSessionItem> items;

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);
  double get total => (subtotal - discount).clamp(0.0, double.infinity);
  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'company_id': companyId,
        'customer_id': customerId,
        'customer_name': customerName,
        'status': cartSessionStatusToJson(status),
        'discount': discount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CartSession.fromMap(Map<String, dynamic> map, {List<CartSessionItem>? items}) => CartSession(
        id: map['id'] as String,
        companyId: map['company_id'] as String,
        customerId: map['customer_id'] as String?,
        customerName: map['customer_name'] as String?,
        status: cartSessionStatusFromJson(map['status'] as String?),
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        items: items,
      );
}

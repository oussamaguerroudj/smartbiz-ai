// Restaurant specialized module domain models (business-specialization
// brief Ch. 17). Same one-file convention as clinic_models.dart.

/// Postgres NUMERIC columns come back over JSON as strings, not
/// numbers  -  parsed centrally here exactly like clinic_models.dart's
/// `_toDouble`.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

enum RestaurantTableStatus { available, occupied, reserved, cleaning }

RestaurantTableStatus _tableStatusFromJson(String raw) => switch (raw) {
      'occupied' => RestaurantTableStatus.occupied,
      'reserved' => RestaurantTableStatus.reserved,
      'cleaning' => RestaurantTableStatus.cleaning,
      _ => RestaurantTableStatus.available,
    };

String restaurantTableStatusToJson(RestaurantTableStatus status) => switch (status) {
      RestaurantTableStatus.available => 'available',
      RestaurantTableStatus.occupied => 'occupied',
      RestaurantTableStatus.reserved => 'reserved',
      RestaurantTableStatus.cleaning => 'cleaning',
    };

class RestaurantTable {
  RestaurantTable({
    required this.id,
    required this.name,
    required this.seats,
    required this.status,
  });

  final String id;
  final String name;
  final int seats;
  final RestaurantTableStatus status;

  factory RestaurantTable.fromJson(Map<String, dynamic> json) => RestaurantTable(
        id: json['id'] as String,
        name: json['name'] as String,
        seats: json['seats'] as int,
        status: _tableStatusFromJson(json['status'] as String),
      );
}

class RestaurantMenuItem {
  RestaurantMenuItem({
    required this.id,
    required this.name,
    this.category,
    required this.price,
    required this.isAvailable,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? category;
  final double price;
  final bool isAvailable;
  final String? imageUrl;

  factory RestaurantMenuItem.fromJson(Map<String, dynamic> json) => RestaurantMenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        price: _toDouble(json['price']),
        isAvailable: json['is_available'] as bool? ?? true,
        imageUrl: json['image_url'] as String?,
      );
}

/// Ch. 17  -  same Paid / Partially paid / Unpaid / Refunded contract as
/// Clinic's ClinicPaymentStatus, never derived on the client.
enum RestaurantPaymentStatus { unpaid, partiallyPaid, paid, refunded }

RestaurantPaymentStatus _paymentStatusFromJson(String? raw) => switch (raw) {
      'partially_paid' => RestaurantPaymentStatus.partiallyPaid,
      'paid' => RestaurantPaymentStatus.paid,
      'refunded' => RestaurantPaymentStatus.refunded,
      _ => RestaurantPaymentStatus.unpaid,
    };

enum RestaurantOrderStatus { pending, preparing, ready, served, completed, cancelled }

RestaurantOrderStatus _orderStatusFromJson(String raw) => switch (raw) {
      'preparing' => RestaurantOrderStatus.preparing,
      'ready' => RestaurantOrderStatus.ready,
      'served' => RestaurantOrderStatus.served,
      'completed' => RestaurantOrderStatus.completed,
      'cancelled' => RestaurantOrderStatus.cancelled,
      _ => RestaurantOrderStatus.pending,
    };

String restaurantOrderStatusToJson(RestaurantOrderStatus status) => switch (status) {
      RestaurantOrderStatus.pending => 'pending',
      RestaurantOrderStatus.preparing => 'preparing',
      RestaurantOrderStatus.ready => 'ready',
      RestaurantOrderStatus.served => 'served',
      RestaurantOrderStatus.completed => 'completed',
      RestaurantOrderStatus.cancelled => 'cancelled',
    };

class RestaurantOrderItem {
  RestaurantOrderItem({
    required this.id,
    this.menuItemId,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  final String id;
  final String? menuItemId;
  final String itemName;
  final double unitPrice;
  final int quantity;
  final double subtotal;

  Map<String, dynamic> toMap(String companyId, String orderId) => {
        'id': id,
        'order_id': orderId,
        'company_id': companyId,
        'menu_item_id': menuItemId,
        'item_name': itemName,
        'unit_price': unitPrice,
        'quantity': quantity,
        'subtotal': subtotal,
      };

  factory RestaurantOrderItem.fromJson(Map<String, dynamic> json) => RestaurantOrderItem(
        id: json['id'] as String,
        menuItemId: json['menu_item_id'] as String?,
        itemName: json['item_name'] as String,
        unitPrice: _toDouble(json['unit_price']),
        quantity: json['quantity'] as int,
        subtotal: _toDouble(json['subtotal']),
      );
}

class RestaurantOrder {
  RestaurantOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.tableId,
    this.tableName,
    this.customerName,
    this.customerId,
    this.orderType = 'dine_in',
    this.customerPhone,
    this.deliveryAddress,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    this.completedAt,
    this.items = const [],
  });

  final String id;
  final int orderNumber;
  final RestaurantOrderStatus status;
  final String? tableId;
  final String? tableName;
  final String? customerName;
  final String? customerId;
  final String orderType;
  final String? customerPhone;
  final String? deliveryAddress;
  final double totalAmount;
  final double amountPaid;
  final RestaurantPaymentStatus paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<RestaurantOrderItem> items;

  double get remaining => (totalAmount - amountPaid).clamp(0, double.infinity);

  bool get isPaid => paymentStatus == RestaurantPaymentStatus.paid;
  bool get isPartiallyPaid => paymentStatus == RestaurantPaymentStatus.partiallyPaid;
  bool get isUnpaid => paymentStatus == RestaurantPaymentStatus.unpaid;
  bool get isPreparationReady =>
      status == RestaurantOrderStatus.ready || status == RestaurantOrderStatus.served;
  bool get canComplete => isPreparationReady && isPaid;

  Map<String, dynamic> toMap(String companyId, {int synced = 1}) => {
        'id': id,
        'company_id': companyId,
        'table_id': tableId,
        'table_name': tableName,
        'order_number': orderNumber,
        'status': restaurantOrderStatusToJson(status),
        'total_amount': totalAmount,
        'amount_paid': amountPaid,
        'payment_status': paymentStatus == RestaurantPaymentStatus.paid
            ? 'paid'
            : paymentStatus == RestaurantPaymentStatus.partiallyPaid
                ? 'partially_paid'
                : paymentStatus == RestaurantPaymentStatus.refunded
                    ? 'refunded'
                    : 'unpaid',
        'notes': notes,
        'customer_name': customerName,
        'customer_id': customerId,
        'order_type': orderType,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'synced': synced,
      };

  factory RestaurantOrder.fromJson(Map<String, dynamic> json) => RestaurantOrder(
        id: json['id'] as String,
        orderNumber: json['order_number'] as int,
        status: _orderStatusFromJson(json['status'] as String),
        tableId: json['table_id'] as String?,
        tableName: json['table_name'] as String?,
        customerName: json['customer_name'] as String?,
        customerId: json['customer_id'] as String?,
        orderType: json['order_type'] as String? ?? (json['table_id'] != null ? 'dine_in' : 'takeaway'),
        customerPhone: json['customer_phone'] as String? ?? json['customerPhone'] as String?,
        deliveryAddress: json['delivery_address'] as String? ?? json['deliveryAddress'] as String?,
        totalAmount: _toDouble(json['total_amount']),
        amountPaid: _toDouble(json['amount_paid']),
        paymentStatus: _paymentStatusFromJson(json['payment_status'] as String?),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
        items: (json['items'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(RestaurantOrderItem.fromJson)
            .toList(),
      );

  RestaurantOrder copyWith({
    String? id,
    int? orderNumber,
    RestaurantOrderStatus? status,
    String? tableId,
    String? tableName,
    String? customerName,
    String? customerId,
    String? orderType,
    String? customerPhone,
    String? deliveryAddress,
    double? totalAmount,
    double? amountPaid,
    RestaurantPaymentStatus? paymentStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? completedAt,
    List<RestaurantOrderItem>? items,
  }) =>
      RestaurantOrder(
        id: id ?? this.id,
        orderNumber: orderNumber ?? this.orderNumber,
        status: status ?? this.status,
        tableId: tableId ?? this.tableId,
        tableName: tableName ?? this.tableName,
        customerName: customerName ?? this.customerName,
        customerId: customerId ?? this.customerId,
        orderType: orderType ?? this.orderType,
        customerPhone: customerPhone ?? this.customerPhone,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        totalAmount: totalAmount ?? this.totalAmount,
        amountPaid: amountPaid ?? this.amountPaid,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt ?? this.completedAt,
        items: items ?? this.items,
      );
}

enum RestaurantReservationStatus { pending, confirmed, seated, cancelled, noShow }

RestaurantReservationStatus _reservationStatusFromJson(String raw) => switch (raw) {
      'confirmed' => RestaurantReservationStatus.confirmed,
      'seated' => RestaurantReservationStatus.seated,
      'cancelled' => RestaurantReservationStatus.cancelled,
      'no_show' => RestaurantReservationStatus.noShow,
      _ => RestaurantReservationStatus.pending,
    };

String restaurantReservationStatusToJson(RestaurantReservationStatus status) => switch (status) {
      RestaurantReservationStatus.pending => 'pending',
      RestaurantReservationStatus.confirmed => 'confirmed',
      RestaurantReservationStatus.seated => 'seated',
      RestaurantReservationStatus.cancelled => 'cancelled',
      RestaurantReservationStatus.noShow => 'no_show',
    };

/// Ch. 8/9-equivalent  -  computed, read-only invoice view (GET
/// /restaurant/orders/:id/invoice). See backend
/// restaurant.service.getOrderInvoice for why this is derived from the
/// order rather than a stored entity.
class RestaurantInvoiceItem {
  RestaurantInvoiceItem({
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String itemName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  factory RestaurantInvoiceItem.fromJson(Map<String, dynamic> json) => RestaurantInvoiceItem(
        itemName: json['itemName'] as String,
        quantity: json['quantity'] as int,
        unitPrice: _toDouble(json['unitPrice']),
        subtotal: _toDouble(json['subtotal']),
      );
}

class RestaurantInvoice {
  RestaurantInvoice({
    required this.invoiceNumber,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.remaining,
    required this.paymentStatus,
    this.tableName,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.orderType,
  });

  final String invoiceNumber;
  final DateTime date;
  final String? tableName;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? orderType;
  final List<RestaurantInvoiceItem> items;
  final double totalAmount;
  final double amountPaid;
  final double remaining;
  final String paymentStatus;

  factory RestaurantInvoice.fromJson(Map<String, dynamic> json) => RestaurantInvoice(
        invoiceNumber: json['invoiceNumber'] as String,
        date: DateTime.parse(json['date'] as String),
        tableName: json['tableName'] as String?,
        customerName: json['customerName'] as String? ?? json['customer_name'] as String?,
        customerPhone: json['customerPhone'] as String? ?? json['customer_phone'] as String?,
        deliveryAddress: json['deliveryAddress'] as String? ?? json['delivery_address'] as String?,
        orderType: json['orderType'] as String? ?? json['order_type'] as String?,
        items: (json['items'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(RestaurantInvoiceItem.fromJson)
            .toList(),
        totalAmount: _toDouble(json['totalAmount']),
        amountPaid: _toDouble(json['amountPaid']),
        remaining: _toDouble(json['remaining']),
        paymentStatus: json['paymentStatus'] as String? ?? 'unpaid',
      );
}

/// Ch. 13/14  -  raw-material/commodity inventory (ingredients, drinks,
/// supplies), distinct from the menu (what's sold) and from the
/// generic CORE Products/Stock tabs (which restaurant accounts don't
/// get  -  see main_shell.dart's _middleTabsFor comment; this is
/// additive, a different concept: what goes INTO dishes, not what's
/// sold directly).
class RestaurantInventoryItem {
  RestaurantInventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.minimumStock,
    required this.purchasePrice,
    this.category,
    this.sellingPrice,
    this.supplier,
    this.expirationDate,
    this.imageUrl,
    this.notes,
  });

  final String id;
  final String name;
  final String? category;
  final String unit;
  final double quantity;
  final double minimumStock;
  final double purchasePrice;
  final double? sellingPrice;
  final String? supplier;
  final DateTime? expirationDate;
  final String? imageUrl;
  final String? notes;

  bool get isLowStock => quantity <= minimumStock;

  factory RestaurantInventoryItem.fromJson(Map<String, dynamic> json) => RestaurantInventoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        unit: json['unit'] as String? ?? 'unit',
        quantity: _toDouble(json['quantity']),
        minimumStock: _toDouble(json['minimum_stock']),
        purchasePrice: _toDouble(json['purchase_price']),
        sellingPrice: json['selling_price'] != null ? _toDouble(json['selling_price']) : null,
        supplier: json['supplier'] as String?,
        expirationDate:
            json['expiration_date'] != null ? DateTime.tryParse(json['expiration_date'] as String) : null,
        imageUrl: json['image_url'] as String?,
        notes: json['notes'] as String?,
      );
}

/// Ch. 16  -  one recipe line: how much of one inventory item one menu
/// item consumes. See backend migration 025's header comment for the
/// "same unit as the inventory item, no conversion" limitation.
class MenuItemIngredient {
  MenuItemIngredient({
    required this.inventoryItemId,
    required this.inventoryItemName,
    required this.unit,
    required this.quantityRequired,
  });

  final String inventoryItemId;
  final String inventoryItemName;
  final String unit;
  final double quantityRequired;

  factory MenuItemIngredient.fromJson(Map<String, dynamic> json) => MenuItemIngredient(
        inventoryItemId: json['inventory_item_id'] as String,
        inventoryItemName: json['inventory_item_name'] as String,
        unit: json['unit'] as String? ?? 'unit',
        quantityRequired: _toDouble(json['quantity_required']),
      );
}

class RestaurantReservation {
  RestaurantReservation({
    required this.id,
    required this.customerName,
    this.phone,
    required this.partySize,
    this.tableId,
    this.tableName,
    required this.reservedAt,
    required this.status,
  });

  final String id;
  final String customerName;
  final String? phone;
  final int partySize;
  final String? tableId;
  final String? tableName;
  final DateTime reservedAt;
  final RestaurantReservationStatus status;

  factory RestaurantReservation.fromJson(Map<String, dynamic> json) => RestaurantReservation(
        id: json['id'] as String,
        customerName: json['customer_name'] as String,
        phone: json['phone'] as String?,
        partySize: json['party_size'] as int,
        tableId: json['table_id'] as String? ?? json['tableId'] as String?,
        tableName: json['table_name'] as String?,
        reservedAt: DateTime.parse(json['reserved_at'] as String),
        status: _reservationStatusFromJson(json['status'] as String),
      );
}

class RestaurantBestSeller {
  RestaurantBestSeller({required this.itemName, required this.unitsSold, required this.revenue});

  final String itemName;
  final int unitsSold;
  final double revenue;

  factory RestaurantBestSeller.fromJson(Map<String, dynamic> json) => RestaurantBestSeller(
        itemName: json['item_name'] as String,
        unitsSold: json['units_sold'] as int,
        revenue: _toDouble(json['revenue']),
      );
}

class RestaurantDashboardStats {
  RestaurantDashboardStats({
    required this.ordersToday,
    required this.activeOrders,
    required this.pendingOrders,
    required this.completedToday,
    required this.cancelledToday,
    required this.tablesTotal,
    required this.tablesOccupied,
    required this.tablesAvailable,
    required this.reservationsToday,
    this.todayRevenue = 0,
    this.weekRevenue = 0,
    this.monthRevenue = 0,
    this.todayExpenses = 0,
    this.todayProfit = 0,
    this.outstandingPayments = 0,
    this.bestSellingDishes = const [],
  });

  final int ordersToday;
  final int activeOrders;
  final int pendingOrders;
  final int completedToday;
  final int cancelledToday;
  final int tablesTotal;
  final int tablesOccupied;
  final int tablesAvailable;
  final int reservationsToday;

  /// Ch. 17  -  revenue = actual order payments, never a separate
  /// product-sale figure; profit = revenue - restaurant expenses.
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final double todayExpenses;
  final double todayProfit;
  final double outstandingPayments;
  final List<RestaurantBestSeller> bestSellingDishes;

  factory RestaurantDashboardStats.fromJson(Map<String, dynamic> json) => RestaurantDashboardStats(
        ordersToday: json['ordersToday'] as int,
        activeOrders: json['activeOrders'] as int,
        pendingOrders: json['pendingOrders'] as int,
        completedToday: json['completedToday'] as int,
        cancelledToday: json['cancelledToday'] as int,
        tablesTotal: json['tablesTotal'] as int,
        tablesOccupied: json['tablesOccupied'] as int,
        tablesAvailable: json['tablesAvailable'] as int,
        reservationsToday: json['reservationsToday'] as int,
        todayRevenue: _toDouble(json['todayRevenue']),
        weekRevenue: _toDouble(json['weekRevenue']),
        monthRevenue: _toDouble(json['monthRevenue']),
        todayExpenses: _toDouble(json['todayExpenses']),
        todayProfit: _toDouble(json['todayProfit']),
        outstandingPayments: _toDouble(json['outstandingPayments']),
        bestSellingDishes: (json['bestSellingDishes'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(RestaurantBestSeller.fromJson)
            .toList(),
      );
}

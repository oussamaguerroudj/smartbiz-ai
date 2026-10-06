import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/restaurant_models.dart';

class RestaurantRepository {
  RestaurantRepository(this._ref);
  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<RestaurantDashboardStats> dashboard() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/restaurant/dashboard');
      return RestaurantDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
    } catch (_) {
      final companyId = _companyId;
      if (companyId == null) {
        return RestaurantDashboardStats(
          ordersToday: 0,
          activeOrders: 0,
          pendingOrders: 0,
          completedToday: 0,
          cancelledToday: 0,
          tablesTotal: 0,
          tablesOccupied: 0,
          tablesAvailable: 0,
          reservationsToday: 0,
        );
      }
      try {
        final db = await AppDatabase.instance.database;
        final todayPrefix = '${DateTime.now().toIso8601String().substring(0, 10)}%';
        final salesRes = await db.rawQuery(
          'SELECT COALESCE(SUM(total), 0) as revenue, COUNT(*) as orders FROM sales WHERE company_id = ? AND sold_at LIKE ?',
          [companyId, todayPrefix],
        );
        final expRes = await db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE company_id = ? AND expense_date LIKE ?',
          [companyId, todayPrefix],
        );
        final rev = (salesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
        final orders = (salesRes.first['orders'] as num?)?.toInt() ?? 0;
        final exp = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;

        return RestaurantDashboardStats(
          ordersToday: orders,
          activeOrders: 0,
          pendingOrders: 0,
          completedToday: orders,
          cancelledToday: 0,
          tablesTotal: 0,
          tablesOccupied: 0,
          tablesAvailable: 0,
          reservationsToday: 0,
          todayRevenue: rev,
          todayExpenses: exp,
          todayProfit: rev - exp,
        );
      } catch (_) {
        return RestaurantDashboardStats(
          ordersToday: 0,
          activeOrders: 0,
          pendingOrders: 0,
          completedToday: 0,
          cancelledToday: 0,
          tablesTotal: 0,
          tablesOccupied: 0,
          tablesAvailable: 0,
          reservationsToday: 0,
        );
      }
    }
  }

  // -- Tables -------------------------------------------------------

  Future<List<RestaurantTable>> listTables() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/tables');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(RestaurantTable.fromJson).toList();
  }

  Future<RestaurantTable> createTable({required String name, int seats = 2}) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/restaurant/tables', body: {'name': name, 'seats': seats});
    return RestaurantTable.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateTableStatus(String tableId, RestaurantTableStatus status) async {
    final client = _ref.read(apiClientProvider);
    await client.patch('/restaurant/tables/$tableId/status', body: {
      'status': restaurantTableStatusToJson(status),
    });
  }

  // -- Menu -----------------------------------------------------------

  Future<List<RestaurantMenuItem>> listMenuItems() async {
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/restaurant/menu-items');
      final rows = (response['data'] as List).cast<Map<String, dynamic>>();
      return rows.map(RestaurantMenuItem.fromJson).toList();
    } catch (_) {
      final companyId = _companyId;
      if (companyId == null) return [];
      try {
        final db = await AppDatabase.instance.database;
        final rows = await db.query(
          'products',
          where: 'company_id = ? AND deleted_at IS NULL',
          whereArgs: [companyId],
          orderBy: 'name ASC',
        );
        return rows.map((r) => RestaurantMenuItem(
          id: r['id'] as String,
          name: r['name'] as String,
          category: r['category'] as String?,
          price: (r['selling_price'] as num?)?.toDouble() ?? 0.0,
          isAvailable: (r['quantity'] as num?)?.toInt() != 0,
        )).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<RestaurantMenuItem> createMenuItem({
    required String name,
    String? category,
    required double price,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/restaurant/menu-items', body: {
      'name': name,
      if (category != null && category.isNotEmpty) 'category': category,
      'price': price,
    });
    return RestaurantMenuItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<RestaurantMenuItem> updateMenuItem({
    required String itemId,
    String? name,
    String? category,
    double? price,
    bool? isAvailable,
    String? imageUrl,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.put('/restaurant/menu-items/$itemId', body: {
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (price != null) 'price': price,
      if (isAvailable != null) 'isAvailable': isAvailable,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
    return RestaurantMenuItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> setMenuItemAvailability(String itemId, bool isAvailable) async {
    final client = _ref.read(apiClientProvider);
    await client.patch('/restaurant/menu-items/$itemId/availability', body: {'isAvailable': isAvailable});
  }

  /// Ch. 17/18 — saves an already-uploaded image
  /// (ImagesRepository.uploadImage(namespace: 'restaurant-menu')) onto
  /// this menu item.
  Future<void> setMenuItemImage(String itemId, String imageUrl) async {
    final client = _ref.read(apiClientProvider);
    await client.patch('/restaurant/menu-items/$itemId/image', body: {'imageUrl': imageUrl});
  }

  Future<void> deleteMenuItem(String itemId) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/restaurant/menu-items/$itemId');
  }

  // -- Orders -----------------------------------------------------------

  Future<void> _upsertOrdersToLocal(List<RestaurantOrder> orders) async {
    final companyId = _companyId;
    if (companyId == null) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();

    for (final o in orders) {
      batch.insert(
        'restaurant_orders',
        o.toMap(companyId, synced: 1),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final item in o.items) {
        batch.insert(
          'restaurant_order_items',
          item.toMap(companyId, o.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<RestaurantOrder>> activeOrders() async {
    final companyId = _companyId;
    List<RestaurantOrder> localOrders = [];
    if (companyId != null) {
      try {
        final db = await AppDatabase.instance.database;
        final rows = await db.query(
          'restaurant_orders',
          where: "company_id = ? AND status IN ('pending', 'preparing', 'ready', 'served')",
          whereArgs: [companyId],
          orderBy: 'order_number ASC',
        );
        for (final r in rows) {
          final itemRows = await db.query(
            'restaurant_order_items',
            where: 'order_id = ? AND company_id = ?',
            whereArgs: [r['id'], companyId],
          );
          final items = itemRows.map(RestaurantOrderItem.fromJson).toList();
          localOrders.add(RestaurantOrder.fromJson({
            ...r,
            'items': items.map((i) => {
                  'id': i.id,
                  'menu_item_id': i.menuItemId,
                  'item_name': i.itemName,
                  'unit_price': i.unitPrice,
                  'quantity': i.quantity,
                  'subtotal': i.subtotal,
                }).toList(),
          }));
        }
      } catch (_) {}
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/restaurant/orders/active');
      final rows = (response['data'] as List).cast<Map<String, dynamic>>();
      final serverOrders = rows.map(RestaurantOrder.fromJson).toList();
      if (companyId != null) {
        await _upsertOrdersToLocal(serverOrders);
      }
      return serverOrders;
    } catch (_) {
      if (localOrders.isNotEmpty) return localOrders;
      rethrow;
    }
  }

  Future<List<RestaurantOrder>> listOrders() async {
    final companyId = _companyId;
    List<RestaurantOrder> localOrders = [];
    if (companyId != null) {
      try {
        final db = await AppDatabase.instance.database;
        final rows = await db.query(
          'restaurant_orders',
          where: 'company_id = ?',
          whereArgs: [companyId],
          orderBy: 'created_at DESC',
        );
        for (final r in rows) {
          final itemRows = await db.query(
            'restaurant_order_items',
            where: 'order_id = ? AND company_id = ?',
            whereArgs: [r['id'], companyId],
          );
          final items = itemRows.map(RestaurantOrderItem.fromJson).toList();
          localOrders.add(RestaurantOrder.fromJson({
            ...r,
            'items': items.map((i) => {
                  'id': i.id,
                  'menu_item_id': i.menuItemId,
                  'item_name': i.itemName,
                  'unit_price': i.unitPrice,
                  'quantity': i.quantity,
                  'subtotal': i.subtotal,
                }).toList(),
          }));
        }
      } catch (_) {}
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/restaurant/orders');
      final rows = (response['data'] as List).cast<Map<String, dynamic>>();
      final serverOrders = rows.map(RestaurantOrder.fromJson).toList();
      if (companyId != null) {
        await _upsertOrdersToLocal(serverOrders);
      }
      return serverOrders;
    } catch (_) {
      if (localOrders.isNotEmpty) return localOrders;
      rethrow;
    }
  }

  Future<RestaurantOrder> orderDetail(String orderId) async {
    final companyId = _companyId;
    if (companyId != null) {
      try {
        final db = await AppDatabase.instance.database;
        final rows = await db.query(
          'restaurant_orders',
          where: 'id = ? AND company_id = ?',
          whereArgs: [orderId, companyId],
        );
        if (rows.isNotEmpty) {
          final itemRows = await db.query(
            'restaurant_order_items',
            where: 'order_id = ? AND company_id = ?',
            whereArgs: [orderId, companyId],
          );
          final items = itemRows.map(RestaurantOrderItem.fromJson).toList();
          final localOrder = RestaurantOrder.fromJson({
            ...rows.first,
            'items': items.map((i) => {
                  'id': i.id,
                  'menu_item_id': i.menuItemId,
                  'item_name': i.itemName,
                  'unit_price': i.unitPrice,
                  'quantity': i.quantity,
                  'subtotal': i.subtotal,
                }).toList(),
          });
          // Try server update in background
          try {
            final client = _ref.read(apiClientProvider);
            final response = await client.get('/restaurant/orders/$orderId');
            final serverOrder = RestaurantOrder.fromJson(response['data'] as Map<String, dynamic>);
            await _upsertOrdersToLocal([serverOrder]);
            return serverOrder;
          } catch (_) {
            return localOrder;
          }
        }
      } catch (_) {}
    }

    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/orders/$orderId');
    final serverOrder = RestaurantOrder.fromJson(response['data'] as Map<String, dynamic>);
    if (companyId != null) {
      await _upsertOrdersToLocal([serverOrder]);
    }
    return serverOrder;
  }

  /// `items` — each entry is either `{menuItemId, quantity}` (pulls the
  /// current menu price/name) or `{name, unitPrice, quantity}`.
  Future<RestaurantOrder> createOrder({
    String? tableId,
    String? tableName,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? customerName,
    String? customerId,
    String? orderType,
    String? customerPhone,
    String? deliveryAddress,
  }) async {
    final companyId = _companyId;
    if (companyId == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated', code: 'NOT_AUTHENTICATED');
    }

    final db = await AppDatabase.instance.database;
    final orderId = const Uuid().v4();
    final now = DateTime.now();
    final resolvedOrderType = orderType ?? (tableId != null ? 'dine_in' : 'takeaway');

    // Next sequential local order number
    final countRes = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM restaurant_orders WHERE company_id = ?',
      [companyId],
    );
    final nextNumber = ((countRes.first['count'] as num?)?.toInt() ?? 0) + 1;

    // Calculate total
    double totalAmount = 0;
    final List<RestaurantOrderItem> orderItems = [];
    for (final it in items) {
      final unitPrice = (it['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      final subtotal = unitPrice * qty;
      totalAmount += subtotal;
      orderItems.add(RestaurantOrderItem(
        id: const Uuid().v4(),
        menuItemId: it['menuItemId'] as String?,
        itemName: it['name'] as String? ?? 'Item',
        unitPrice: unitPrice,
        quantity: qty,
        subtotal: subtotal,
      ));
    }

    final localOrder = RestaurantOrder(
      id: orderId,
      orderNumber: nextNumber,
      status: RestaurantOrderStatus.pending,
      tableId: tableId,
      tableName: tableName,
      customerName: customerName,
      customerId: customerId,
      orderType: resolvedOrderType,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      totalAmount: totalAmount,
      amountPaid: 0,
      paymentStatus: RestaurantPaymentStatus.unpaid,
      notes: notes,
      createdAt: now,
      items: orderItems,
    );

    // Save locally to SQLite
    await db.insert(
      'restaurant_orders',
      localOrder.toMap(companyId, synced: 0),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (final oi in orderItems) {
      await db.insert(
        'restaurant_order_items',
        oi.toMap(companyId, orderId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Try online sync
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.post('/restaurant/orders', body: {
        if (tableId != null) 'tableId': tableId,
        'items': items,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (customerName != null) 'customerName': customerName,
        if (customerId != null) 'customerId': customerId,
        'orderType': resolvedOrderType,
        if (customerPhone != null && customerPhone.isNotEmpty) 'customerPhone': customerPhone,
        if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
      });
      final serverOrder = RestaurantOrder.fromJson(response['data'] as Map<String, dynamic>);
      await _upsertOrdersToLocal([serverOrder]);
      return serverOrder;
    } catch (_) {
      // Offline fallback: enqueue to sync
      await _ref.read(syncServiceProvider.notifier).enqueueOperation(
            id: const Uuid().v4(),
            clientTransactionId: const Uuid().v4(),
            entityType: 'restaurant_order',
            entityId: orderId,
            operationType: 'CREATE',
            payload: {
              'tableId': tableId,
              'items': items,
              'notes': notes,
              'customerName': customerName,
              'customerId': customerId,
              'orderType': resolvedOrderType,
              'customerPhone': customerPhone,
              'deliveryAddress': deliveryAddress,
            },
          );
      return localOrder;
    }
  }

  Future<RestaurantOrder> updateOrder({
    required String orderId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? notes,
    String? tableId,
    bool clearPhone = false,
    bool clearAddress = false,
    bool clearTable = false,
  }) async {
    final companyId = _companyId;
    final db = await AppDatabase.instance.database;

    final updates = <String, dynamic>{};
    if (customerName != null) updates['customer_name'] = customerName;
    if (clearPhone) {
      updates['customer_phone'] = null;
    } else if (customerPhone != null) {
      updates['customer_phone'] = customerPhone;
    }
    if (clearAddress) {
      updates['delivery_address'] = null;
    } else if (deliveryAddress != null) {
      updates['delivery_address'] = deliveryAddress;
    }
    if (clearTable) {
      updates['table_id'] = null;
    } else if (tableId != null) {
      updates['table_id'] = tableId;
    }
    if (notes != null) updates['notes'] = notes;

    if (companyId != null && updates.isNotEmpty) {
      await db.update(
        'restaurant_orders',
        updates,
        where: 'id = ? AND company_id = ?',
        whereArgs: [orderId, companyId],
      );
    }

    final payload = <String, dynamic>{
      'id': orderId,
      if (customerName != null) 'customerName': customerName,
      'customerPhone': clearPhone ? null : (customerPhone ?? updates['customer_phone']),
      'deliveryAddress': clearAddress ? null : (deliveryAddress ?? updates['delivery_address']),
      if (notes != null) 'notes': notes,
      if (clearTable) 'tableId': null else if (tableId != null) 'tableId': tableId,
    };

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.put('/restaurant/orders/$orderId', body: payload);
      final serverOrder = RestaurantOrder.fromJson(response['data'] as Map<String, dynamic>);
      if (companyId != null) {
        await _upsertOrdersToLocal([serverOrder]);
      }
      return serverOrder;
    } catch (_) {
      // Offline fallback: enqueue operation
      if (companyId != null) {
        await _ref.read(syncServiceProvider.notifier).enqueueOperation(
              id: const Uuid().v4(),
              clientTransactionId: const Uuid().v4(),
              entityType: 'restaurant_order',
              entityId: orderId,
              operationType: 'UPDATE',
              payload: payload,
            );
      }
      return orderDetail(orderId);
    }
  }

  Future<void> updateOrderStatus(String orderId, RestaurantOrderStatus status) async {
    final companyId = _companyId;

    // Load order to verify completion rules
    if (status == RestaurantOrderStatus.completed) {
      RestaurantOrder? existing;
      try {
        existing = await orderDetail(orderId);
      } catch (_) {}

      if (existing != null) {
        if (existing.status != RestaurantOrderStatus.ready &&
            existing.status != RestaurantOrderStatus.served) {
          throw ApiException(
            statusCode: 400,
            message: 'Order is not ready yet',
            code: 'ORDER_NOT_READY',
          );
        }
        if (existing.paymentStatus != RestaurantPaymentStatus.paid || existing.remaining > 0) {
          throw ApiException(
            statusCode: 400,
            message: 'Order payment is required before completion',
            code: 'ORDER_PAYMENT_REQUIRED',
          );
        }
      }
    }

    // Update local SQLite
    if (companyId != null) {
      try {
        final db = await AppDatabase.instance.database;
        await db.update(
          'restaurant_orders',
          {
            'status': restaurantOrderStatusToJson(status),
            'updated_at': DateTime.now().toIso8601String(),
            if (status == RestaurantOrderStatus.completed)
              'completed_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND company_id = ?',
          whereArgs: [orderId, companyId],
        );
      } catch (_) {}
    }

    // Try online
    try {
      final client = _ref.read(apiClientProvider);
      await client.patch('/restaurant/orders/$orderId/status', body: {
        'status': restaurantOrderStatusToJson(status),
      });
    } catch (e) {
      if (e is ApiException &&
          (e.code == 'ORDER_PAYMENT_REQUIRED' || e.code == 'ORDER_NOT_READY')) {
        rethrow;
      }
      // Offline fallback: enqueue to sync
      await _ref.read(syncServiceProvider.notifier).enqueueOperation(
            id: const Uuid().v4(),
            clientTransactionId: const Uuid().v4(),
            entityType: 'restaurant_order',
            entityId: orderId,
            operationType: 'UPDATE_STATUS',
            payload: {
              'id': orderId,
              'status': restaurantOrderStatusToJson(status),
            },
          );
    }
  }

  Future<void> completeOrder(String orderId) async {
    await updateOrderStatus(orderId, RestaurantOrderStatus.completed);
  }

  Future<void> recordPayment(
    String orderId, {
    required double amount,
    String? method,
    String? note,
  }) async {
    final companyId = _companyId;
    if (companyId == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated', code: 'NOT_AUTHENTICATED');
    }

    // Update local SQLite
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'restaurant_orders',
      where: 'id = ? AND company_id = ?',
      whereArgs: [orderId, companyId],
    );

    if (rows.isNotEmpty) {
      final orderRow = rows.first;
      final total = (orderRow['total_amount'] as num?)?.toDouble() ?? 0.0;
      final currentPaid = (orderRow['amount_paid'] as num?)?.toDouble() ?? 0.0;
      final newPaid = currentPaid + amount;
      final newStatus = newPaid >= total
          ? 'paid'
          : newPaid > 0
              ? 'partially_paid'
              : 'unpaid';

      await db.update(
        'restaurant_orders',
        {
          'amount_paid': newPaid,
          'payment_status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND company_id = ?',
        whereArgs: [orderId, companyId],
      );

      await db.insert('restaurant_payments', {
        'id': const Uuid().v4(),
        'company_id': companyId,
        'order_id': orderId,
        'amount': amount,
        'method': method ?? 'cash',
        'note': note,
        'paid_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.post('/restaurant/orders/$orderId/payments', body: {
        'amount': amount,
        if (method != null && method.isNotEmpty) 'method': method,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (response is Map && response['data'] is Map && response['data']['order'] is Map) {
        final updatedServerOrder = RestaurantOrder.fromJson(response['data']['order'] as Map<String, dynamic>);
        await _upsertOrdersToLocal([updatedServerOrder]);
      }
    } catch (_) {
      // Offline fallback: enqueue to sync
      await _ref.read(syncServiceProvider.notifier).enqueueOperation(
            id: const Uuid().v4(),
            clientTransactionId: const Uuid().v4(),
            entityType: 'restaurant_order',
            entityId: orderId,
            operationType: 'RECORD_PAYMENT',
            payload: {
              'orderId': orderId,
              'amount': amount,
              'method': method,
              'note': note,
            },
          );
    }
  }

  Future<void> refundOrder(String orderId, {String? note}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/restaurant/orders/$orderId/refund', body: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<RestaurantInvoice> getOrderInvoice(String orderId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/orders/$orderId/invoice');
    return RestaurantInvoice.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Uint8List> fetchOrderInvoicePdf(String orderId) async {
    final client = _ref.read(apiClientProvider);
    return client.getBytes('/restaurant/orders/$orderId/invoice/pdf');
  }

  // -- Reservations -------------------------------------------------------

  Future<List<RestaurantReservation>> listReservations() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/reservations');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(RestaurantReservation.fromJson).toList();
  }

  Future<RestaurantReservation> createReservation({
    required String customerName,
    String? phone,
    int partySize = 1,
    String? tableId,
    required DateTime reservedAt,
    String? notes,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/restaurant/reservations', body: {
      'customerName': customerName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'partySize': partySize,
      if (tableId != null) 'tableId': tableId,
      'reservedAt': reservedAt.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return RestaurantReservation.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateReservationStatus(String reservationId, RestaurantReservationStatus status) async {
    final client = _ref.read(apiClientProvider);
    await client.patch('/restaurant/reservations/$reservationId/status', body: {
      'status': restaurantReservationStatusToJson(status),
    });
  }

  Future<RestaurantReservation> updateReservation({
    required String reservationId,
    String? customerName,
    String? phone,
    int? partySize,
    String? tableId,
    bool clearTable = false,
    DateTime? reservedAt,
    String? notes,
    RestaurantReservationStatus? status,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.put('/restaurant/reservations/$reservationId', body: {
      if (customerName != null) 'customerName': customerName,
      if (phone != null) 'phone': phone,
      if (partySize != null) 'partySize': partySize,
      if (clearTable) 'tableId': null else if (tableId != null) 'tableId': tableId,
      if (reservedAt != null) 'reservedAt': reservedAt.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (status != null) 'status': restaurantReservationStatusToJson(status),
    });
    return RestaurantReservation.fromJson(response['data'] as Map<String, dynamic>);
  }

  // ---- Inventory (Ch. 13/14/15) ----

  Future<RestaurantInventoryItem> createInventoryItem({
    required String name,
    String? category,
    String? unit,
    double? minimumStock,
    double? purchasePrice,
    double? sellingPrice,
    String? supplier,
    double? openingQuantity,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/restaurant/inventory', body: {
      'name': name,
      if (category != null && category.isNotEmpty) 'category': category,
      if (unit != null && unit.isNotEmpty) 'unit': unit,
      if (minimumStock != null) 'minimumStock': minimumStock,
      if (purchasePrice != null) 'purchasePrice': purchasePrice,
      if (sellingPrice != null) 'sellingPrice': sellingPrice,
      if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
      if (openingQuantity != null) 'openingQuantity': openingQuantity,
    });
    return RestaurantInventoryItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<RestaurantInventoryItem>> listInventoryItems({String? search, bool lowStockOnly = false}) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/inventory', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (lowStockOnly) 'lowStockOnly': 'true',
    });
    return (response['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(RestaurantInventoryItem.fromJson)
        .toList();
  }

  Future<void> archiveInventoryItem(String itemId) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/restaurant/inventory/$itemId');
  }

  /// Ch. 14 manual adjustment AND Ch. 15's AI-scan-confirm landing spot
  /// — see restaurant.service.adjustInventoryQuantity's doc comment.
  Future<RestaurantInventoryItem> adjustInventoryQuantity(
    String itemId, {
    required String movementType,
    required double quantityChange,
    String? reference,
    String? note,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/restaurant/inventory/$itemId/adjust', body: {
      'movementType': movementType,
      'quantityChange': quantityChange,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return RestaurantInventoryItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Ch. 17/18 — saves an already-uploaded image (via
  /// ImagesRepository.uploadImage(namespace: 'restaurant-inventory'))
  /// onto this item.
  Future<RestaurantInventoryItem> updateInventoryItemImage(String itemId, String imageUrl) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.patch('/restaurant/inventory/$itemId', body: {'imageUrl': imageUrl});
    return RestaurantInventoryItem.fromJson(response['data'] as Map<String, dynamic>);
  }

  // ---- Recipes / BOM (Ch. 16) ----

  Future<List<MenuItemIngredient>> getMenuItemIngredients(String menuItemId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/menu-items/$menuItemId/ingredients');
    return (response['data'] as List)
        .cast<Map<String, dynamic>>()
        .map(MenuItemIngredient.fromJson)
        .toList();
  }

  Future<void> setMenuItemIngredients(
    String menuItemId,
    List<({String inventoryItemId, double quantityRequired})> lines,
  ) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/restaurant/menu-items/$menuItemId/ingredients', body: {
      'lines': lines
          .map((l) => {'inventoryItemId': l.inventoryItemId, 'quantityRequired': l.quantityRequired})
          .toList(),
    });
  }
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) => RestaurantRepository(ref));

final restaurantDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.read(restaurantRepositoryProvider).dashboard();
});

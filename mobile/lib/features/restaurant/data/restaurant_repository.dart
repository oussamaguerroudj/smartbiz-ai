import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/restaurant_models.dart';

class RestaurantRepository {
  RestaurantRepository(this._ref);
  final Ref _ref;

  Future<RestaurantDashboardStats> dashboard() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/dashboard');
    return RestaurantDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
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
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/menu-items');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(RestaurantMenuItem.fromJson).toList();
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

  Future<List<RestaurantOrder>> activeOrders() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/orders/active');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(RestaurantOrder.fromJson).toList();
  }

  Future<List<RestaurantOrder>> listOrders() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/orders');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(RestaurantOrder.fromJson).toList();
  }

  Future<RestaurantOrder> orderDetail(String orderId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/restaurant/orders/$orderId');
    return RestaurantOrder.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// `items` — each entry is either `{menuItemId, quantity}` (pulls the
  /// current menu price/name server-side) or `{name, unitPrice,
  /// quantity}` for a free-form line.
  Future<RestaurantOrder> createOrder({
    String? tableId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/restaurant/orders', body: {
      if (tableId != null) 'tableId': tableId,
      'items': items,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return RestaurantOrder.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateOrderStatus(String orderId, RestaurantOrderStatus status) async {
    final client = _ref.read(apiClientProvider);
    await client.patch('/restaurant/orders/$orderId/status', body: {
      'status': restaurantOrderStatusToJson(status),
    });
  }

  Future<void> recordPayment(String orderId, {required double amount, String? method, String? note}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/restaurant/orders/$orderId/payments', body: {
      'amount': amount,
      if (method != null && method.isNotEmpty) 'method': method,
      if (note != null && note.isNotEmpty) 'note': note,
    });
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

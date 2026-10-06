import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/session.dart';
import '../../products/domain/product.dart';
import '../domain/cart_session.dart';
import '../domain/sale.dart';
import 'sales_repository.dart';

class MultiCartState {
  MultiCartState({
    required this.carts,
    required this.activeCartId,
    this.isLoading = false,
  });

  final List<CartSession> carts;
  final String activeCartId;
  final bool isLoading;

  CartSession? get activeCart {
    final idx = carts.indexWhere((c) => c.id == activeCartId);
    if (idx >= 0) return carts[idx];
    return carts.isNotEmpty ? carts.first : null;
  }

  List<CartSession> get activeCarts =>
      carts.where((c) => c.status == CartSessionStatus.active || c.status == CartSessionStatus.onHold).toList();

  MultiCartState copyWith({
    List<CartSession>? carts,
    String? activeCartId,
    bool? isLoading,
  }) {
    return MultiCartState(
      carts: carts ?? this.carts,
      activeCartId: activeCartId ?? this.activeCartId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CartManager extends StateNotifier<MultiCartState> {
  CartManager(this._ref) : super(MultiCartState(carts: [], activeCartId: '', isLoading: true)) {
    loadCarts();
  }

  final Ref _ref;
  static const _uuid = Uuid();

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> loadCarts() async {
    final companyId = _companyId;
    if (companyId == null) {
      state = MultiCartState(carts: [], activeCartId: '');
      return;
    }

    state = state.copyWith(isLoading: true);
    final db = await AppDatabase.instance.database;

    // Load active and on-hold carts for this tenant
    final cartRows = await db.query(
      'cart_sessions',
      where: "company_id = ? AND status IN ('ACTIVE', 'ON_HOLD')",
      whereArgs: [companyId],
      orderBy: 'created_at ASC',
    );

    final List<CartSession> loadedCarts = [];
    for (final cRow in cartRows) {
      final cartId = cRow['id'] as String;
      final itemRows = await db.query(
        'cart_session_items',
        where: 'cart_session_id = ? AND company_id = ?',
        whereArgs: [cartId, companyId],
      );
      final items = itemRows.map(CartSessionItem.fromMap).toList();
      loadedCarts.add(CartSession.fromMap(cRow, items: items));
    }

    state = MultiCartState(
      carts: loadedCarts,
      activeCartId: loadedCarts.isNotEmpty ? loadedCarts.first.id : '',
    );
  }

  Future<CartSession> _createNewCartInternal(
    Database db,
    String companyId,
    String defaultName, {
    String? customerId,
    String? customerName,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final name = customerName ?? defaultName;

    final cart = CartSession(
      id: id,
      companyId: companyId,
      customerId: customerId,
      customerName: name,
      status: CartSessionStatus.active,
      createdAt: now,
      updatedAt: now,
      items: [],
    );

    await db.insert(
      'cart_sessions',
      cart.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return cart;
  }

  Future<CartSession> createNewCart({String? customerName, String? customerId}) async {
    final companyId = _companyId;
    if (companyId == null) throw Exception('Not authenticated');

    final db = await AppDatabase.instance.database;
    final nextNum = state.carts.length + 1;
    final defaultName = 'Client $nextNum';

    final newCart = await _createNewCartInternal(
      db,
      companyId,
      defaultName,
      customerId: customerId,
      customerName: customerName,
    );

    final updated = [...state.carts, newCart];
    state = state.copyWith(carts: updated, activeCartId: newCart.id);
    return newCart;
  }

  void switchCart(String cartId) {
    if (state.carts.any((c) => c.id == cartId)) {
      state = state.copyWith(activeCartId: cartId);
    }
  }

  Future<bool> addOrIncrementItem(Product product, {int quantity = 1}) async {
    final companyId = _companyId;
    final cart = state.activeCart;
    if (companyId == null || cart == null) return false;

    final db = await AppDatabase.instance.database;
    final existingIdx = cart.items.indexWhere((i) => i.productId == product.id);

    if (existingIdx >= 0) {
      final item = cart.items[existingIdx];
      final newQty = item.quantity + quantity;
      if (newQty > product.quantity) {
        return false; // Stock limit reached
      }
      item.quantity = newQty;
      await db.update(
        'cart_session_items',
        {'quantity': newQty},
        where: 'id = ? AND company_id = ?',
        whereArgs: [item.id, companyId],
      );
    } else {
      if (product.quantity < quantity) {
        return false; // Out of stock
      }
      final newItem = CartSessionItem(
        id: _uuid.v4(),
        cartSessionId: cart.id,
        productId: product.id,
        productName: product.name,
        unitPrice: product.sellingPrice,
        unitCost: product.purchasePrice,
        quantity: quantity,
      );
      cart.items.add(newItem);
      await db.insert('cart_session_items', newItem.toMap(companyId));
    }

    cart.updatedAt = DateTime.now();
    await db.update(
      'cart_sessions',
      {'updated_at': cart.updatedAt.toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    state = state.copyWith(carts: [...state.carts]);
    return true;
  }

  Future<void> updateQuantity(String productId, int delta) async {
    final companyId = _companyId;
    final cart = state.activeCart;
    if (companyId == null || cart == null) return;

    final idx = cart.items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;

    final item = cart.items[idx];
    final newQty = item.quantity + delta;
    final db = await AppDatabase.instance.database;

    if (newQty <= 0) {
      cart.items.removeAt(idx);
      await db.delete(
        'cart_session_items',
        where: 'id = ? AND company_id = ?',
        whereArgs: [item.id, companyId],
      );
    } else {
      item.quantity = newQty;
      await db.update(
        'cart_session_items',
        {'quantity': newQty},
        where: 'id = ? AND company_id = ?',
        whereArgs: [item.id, companyId],
      );
    }

    cart.updatedAt = DateTime.now();
    await db.update(
      'cart_sessions',
      {'updated_at': cart.updatedAt.toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    state = state.copyWith(carts: [...state.carts]);
  }

  Future<void> removeItem(String productId) async {
    final companyId = _companyId;
    final cart = state.activeCart;
    if (companyId == null || cart == null) return;

    final idx = cart.items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;

    final item = cart.items.removeAt(idx);
    final db = await AppDatabase.instance.database;
    await db.delete(
      'cart_session_items',
      where: 'id = ? AND company_id = ?',
      whereArgs: [item.id, companyId],
    );

    state = state.copyWith(carts: [...state.carts]);
  }

  Future<void> clearActiveCart() async {
    final companyId = _companyId;
    final cart = state.activeCart;
    if (companyId == null || cart == null) return;

    final db = await AppDatabase.instance.database;
    cart.items.clear();
    await db.delete(
      'cart_session_items',
      where: 'cart_session_id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    state = state.copyWith(carts: [...state.carts]);
  }

  Future<void> setDiscount(double discount) async {
    final companyId = _companyId;
    final cart = state.activeCart;
    if (companyId == null || cart == null) return;

    cart.discount = discount;
    final db = await AppDatabase.instance.database;
    await db.update(
      'cart_sessions',
      {'discount': discount, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    state = state.copyWith(carts: [...state.carts]);
  }

  Future<void> holdActiveCart() async {
    final companyId = _companyId;
    final cart = state.activeCart;
    if (companyId == null || cart == null) return;

    final db = await AppDatabase.instance.database;
    cart.status = CartSessionStatus.onHold;
    cart.updatedAt = DateTime.now();

    await db.update(
      'cart_sessions',
      {'status': 'ON_HOLD', 'updated_at': cart.updatedAt.toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    // Switch to another active cart if available, or create a new one
    final otherActive = state.carts.where((c) => c.id != cart.id && c.status == CartSessionStatus.active).toList();
    if (otherActive.isNotEmpty) {
      state = state.copyWith(activeCartId: otherActive.first.id, carts: [...state.carts]);
    } else {
      await createNewCart();
    }
  }

  Future<void> resumeCart(String cartId) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final idx = state.carts.indexWhere((c) => c.id == cartId);
    if (idx < 0) return;

    final cart = state.carts[idx];
    cart.status = CartSessionStatus.active;
    cart.updatedAt = DateTime.now();

    final db = await AppDatabase.instance.database;
    await db.update(
      'cart_sessions',
      {'status': 'ACTIVE', 'updated_at': cart.updatedAt.toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    state = state.copyWith(activeCartId: cart.id, carts: [...state.carts]);
  }

  Future<void> deleteCart(String cartId) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    await db.delete('cart_session_items', where: 'cart_session_id = ? AND company_id = ?', whereArgs: [cartId, companyId]);
    await db.delete('cart_sessions', where: 'id = ? AND company_id = ?', whereArgs: [cartId, companyId]);

    final remaining = state.carts.where((c) => c.id != cartId).toList();
    if (remaining.isEmpty) {
      state = MultiCartState(carts: [], activeCartId: '');
    } else {
      final nextActive = state.activeCartId == cartId ? remaining.first.id : state.activeCartId;
      state = MultiCartState(carts: remaining, activeCartId: nextActive);
    }
  }

  Future<void> updateCustomer({String? customerId, String? customerName}) async {
    final companyId = _companyId;
    final cart = state.activeCart;
    if (companyId == null || cart == null) return;

    cart.customerId = customerId;
    if (customerName != null) {
      cart.customerName = customerName;
    }
    cart.updatedAt = DateTime.now();

    final db = await AppDatabase.instance.database;
    await db.update(
      'cart_sessions',
      {
        'customer_id': customerId,
        'customer_name': cart.customerName,
        'updated_at': cart.updatedAt.toIso8601String(),
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    state = state.copyWith(carts: [...state.carts]);
  }

  /// Completes sale for active cart, marks it COMPLETED in SQLite, and transitions to next/new cart.
  Future<Map<String, dynamic>> checkoutActiveCart(SalesRepository salesRepo) async {
    final cart = state.activeCart;
    final companyId = _companyId;
    if (cart == null || companyId == null) throw Exception('No active cart');
    if (cart.items.isEmpty) throw Exception('Cart is empty');

    final itemsInput = cart.items
        .map((i) => SaleItemInput(
              productId: i.productId,
              productName: i.productName,
              quantity: i.quantity,
            ))
        .toList();

    // Execute atomic sale in sales repository
    final result = await salesRepo.createSale(
      items: itemsInput,
      discount: cart.discount,
      paymentStatus: PaymentStatus.paid,
      customerId: cart.customerId,
    );

    // Mark cart session completed in SQLite
    final db = await AppDatabase.instance.database;
    await db.delete('cart_session_items', where: 'cart_session_id = ? AND company_id = ?', whereArgs: [cart.id, companyId]);
    await db.update(
      'cart_sessions',
      {'status': 'COMPLETED', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND company_id = ?',
      whereArgs: [cart.id, companyId],
    );

    // Remove from in-memory active list
    final remaining = state.carts.where((c) => c.id != cart.id && c.status != CartSessionStatus.completed).toList();
    if (remaining.isEmpty) {
      state = MultiCartState(carts: [], activeCartId: '');
    } else {
      state = MultiCartState(carts: remaining, activeCartId: remaining.first.id);
    }

    return result;
  }
}

final multiCartProvider = StateNotifierProvider<CartManager, MultiCartState>((ref) {
  ref.watch(sessionProvider.select((s) => s.companyId));
  return CartManager(ref);
});

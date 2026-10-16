import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../domain/product.dart';

class ProductsRepository extends StateNotifier<AsyncValue<List<Product>>> {
  final Ref _ref;

  ProductsRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> load({String? search}) async {
    try {
      final local = await _fetchFromLocal(search: search);
      if (mounted) state = AsyncValue.data(local);
    } catch (_) {}

    try {
      final client = _ref.read(apiClientProvider);
      final res = await client.get('/products', query: (search != null && search.isNotEmpty) ? {'search': search} : null);
      final rawList = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
      final serverProducts = rawList.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();

      await _upsertToLocal(serverProducts);

      final fresh = await _fetchFromLocal(search: search);
      if (mounted) state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (mounted && !state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<List<Product>> _fetchFromLocal({String? search}) async {
    final companyId = _companyId;
    if (companyId == null) return [];

    final db = await ModiriDesktopDatabase.instance.database;
    List<Map<String, dynamic>> rows;
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      rows = await db.query(
        'products',
        where: 'company_id = ? AND (name LIKE ? OR barcode LIKE ? OR category LIKE ?)',
        whereArgs: [companyId, q, q, q],
        orderBy: 'name ASC',
      );
    } else {
      rows = await db.query(
        'products',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
    }
    return rows.map((r) => Product.fromJson(r)).toList();
  }

  Future<void> _upsertToLocal(List<Product> products) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await ModiriDesktopDatabase.instance.database;
    final pendingRows = await db.query(
      'sync_queue',
      columns: ['entity_id', 'operation_type'],
      where: "company_id = ? AND entity_type = 'product' AND status = 'pending'",
      whereArgs: [companyId],
    );
    final pendingIds = pendingRows.map((r) => r['entity_id']?.toString()).toSet();

    final batch = db.batch();
    for (final p in products) {
      if (pendingIds.contains(p.id)) continue;
      batch.insert(
        'products',
        {
          'id': p.id,
          'company_id': companyId,
          'name': p.name,
          'price': p.price,
          'cost_price': p.costPrice,
          'stock_quantity': p.stockQuantity,
          'minimum_stock': p.minimumStock,
          'barcode': p.barcode,
          'category': p.category,
          'expiration_date': p.expirationDate?.toIso8601String().substring(0, 10),
          'size': p.size,
          'color': p.color,
          'brand': p.brand,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Product> addProduct({
    required String name,
    required String category,
    required double costPrice,
    required double price,
    required int stockQuantity,
    int minimumStock = 5,
    String? barcode,
    DateTime? expirationDate,
    String? size,
    String? color,
    String? brand,
  }) async {
    final companyId = _companyId ?? 'default_company';
    final newId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();

    final newProduct = Product(
      id: newId,
      companyId: companyId,
      name: name,
      category: category,
      costPrice: costPrice,
      price: price,
      stockQuantity: stockQuantity,
      minimumStock: minimumStock,
      barcode: barcode,
      expirationDate: expirationDate,
      size: size,
      color: color,
      brand: brand,
    );

    // 1. Save locally to SQLite first
    final db = await ModiriDesktopDatabase.instance.database;
    await db.insert('products', {
      'id': newId,
      'company_id': companyId,
      'name': name,
      'category': category,
      'cost_price': costPrice,
      'price': price,
      'stock_quantity': stockQuantity,
      'minimum_stock': minimumStock,
      'barcode': barcode,
      'expiration_date': expirationDate?.toIso8601String().substring(0, 10),
      'size': size,
      'color': color,
      'brand': brand,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    // 2. Immediately update in-memory state
    final fresh = await _fetchFromLocal();
    if (mounted) state = AsyncValue.data(fresh);

    // 3. Enqueue offline-safe sync operation (triggers syncPending once)
    await _ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
      id: const Uuid().v4(),
      clientTransactionId: const Uuid().v4(),
      entityType: 'product',
      entityId: newId,
      operationType: 'CREATE',
      payload: {
        'id': newId,
        'name': name,
        'category': category,
        'purchasePrice': costPrice,
        'purchase_price': costPrice,
        'sellingPrice': price,
        'selling_price': price,
        'price': price,
        'quantity': stockQuantity,
        'stock_quantity': stockQuantity,
        'minimumStock': minimumStock,
        'minimum_stock': minimumStock,
        if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
        if (expirationDate != null) 'expirationDate': expirationDate.toIso8601String().substring(0, 10),
        if (size != null && size.isNotEmpty) 'size': size,
        if (color != null && color.isNotEmpty) 'color': color,
        if (brand != null && brand.isNotEmpty) 'brand': brand,
      },
    );

    return newProduct;
  }

  Future<void> updateProduct(Product product) async {
    final companyId = _companyId ?? 'default_company';
    final db = await ModiriDesktopDatabase.instance.database;

    await db.update(
      'products',
      {
        'name': product.name,
        'category': product.category,
        'cost_price': product.costPrice,
        'price': product.price,
        'stock_quantity': product.stockQuantity,
        'minimum_stock': product.minimumStock,
        'barcode': product.barcode,
        'expiration_date': product.expirationDate?.toIso8601String().substring(0, 10),
        'size': product.size,
        'color': product.color,
        'brand': product.brand,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [product.id, companyId],
    );

    final fresh = await _fetchFromLocal();
    if (mounted) state = AsyncValue.data(fresh);

    await _ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
      id: const Uuid().v4(),
      clientTransactionId: const Uuid().v4(),
      entityType: 'product',
      entityId: product.id,
      operationType: 'UPDATE',
      payload: {
        'name': product.name,
        'category': product.category,
        'purchasePrice': product.costPrice,
        'purchase_price': product.costPrice,
        'sellingPrice': product.price,
        'selling_price': product.price,
        'price': product.price,
        'quantity': product.stockQuantity,
        'stock_quantity': product.stockQuantity,
        'minimumStock': product.minimumStock,
        'minimum_stock': product.minimumStock,
        if (product.barcode != null && product.barcode!.isNotEmpty) 'barcode': product.barcode,
        if (product.expirationDate != null) 'expirationDate': product.expirationDate!.toIso8601String().substring(0, 10),
        if (product.size != null && product.size!.isNotEmpty) 'size': product.size,
        if (product.color != null && product.color!.isNotEmpty) 'color': product.color,
        if (product.brand != null && product.brand!.isNotEmpty) 'brand': product.brand,
      },
    );
  }

  Future<void> deleteProduct(String id) async {
    final companyId = _companyId ?? 'default_company';
    final db = await ModiriDesktopDatabase.instance.database;

    await db.delete('products', where: 'id = ? AND company_id = ?', whereArgs: [id, companyId]);

    final fresh = await _fetchFromLocal();
    if (mounted) state = AsyncValue.data(fresh);

    await _ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
      id: const Uuid().v4(),
      clientTransactionId: const Uuid().v4(),
      entityType: 'product',
      entityId: id,
      operationType: 'DELETE',
      payload: {'id': id},
    );
  }
}

final productsRepositoryProvider =
    StateNotifierProvider<ProductsRepository, AsyncValue<List<Product>>>((ref) {
  ref.watch(sessionProvider.select((s) => s.companyId));
  return ProductsRepository(ref);
});

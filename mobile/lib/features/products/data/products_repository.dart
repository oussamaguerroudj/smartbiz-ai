import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/product.dart';

class ProductsRepository extends StateNotifier<AsyncValue<List<Product>>> {
  ProductsRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  /// Returns the active company ID from the session.
  /// If null (not logged in), all local reads return empty — preventing any
  /// data from leaking to an unauthenticated state.
  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> load({String? search}) async {
    // 1. Immediately read from local SQLite (instant startup & offline support)
    try {
      final localProducts = await _fetchFromLocal(search: search);
      if (!mounted) return;
      state = AsyncValue.data(localProducts);
    } catch (_) {}

    // 2. Fetch from backend in the background if possible
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get(
        '/products',
        query: (search != null && search.isNotEmpty) ? {'search': search} : null,
      );
      final serverProducts = (response['data'] as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      // Upsert server products into local SQLite
      await _upsertToLocal(serverProducts);

      // Re-read authoritative local state
      final fresh = await _fetchFromLocal(search: search);
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (!mounted) return;
      // If we already have local state (even empty list), DO NOT show an error!
      if (state.hasValue) {
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Product>> _fetchFromLocal({String? search}) async {
    final companyId = _companyId;
    // TENANT ISOLATION: never return any records when no company is active.
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
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

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert(
        'products',
        {
          'id': p.id,
          'company_id': companyId,
          'name': p.name,
          'category': p.category,
          'purchase_price': p.purchasePrice,
          'selling_price': p.sellingPrice,
          'quantity': p.quantity,
          'minimum_stock': p.minimumStock,
          'barcode': p.barcode,
          'expiration_date': p.expirationDate?.toIso8601String().substring(0, 10),
          'image_url': p.imageUrl,
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

  Future<void> addProduct({
    required String name,
    required String category,
    required double purchasePrice,
    required double sellingPrice,
    required int quantity,
    int minimumStock = 5,
    String? barcode,
    DateTime? expirationDate,
    String? size,
    String? color,
    String? brand,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final newId = const Uuid().v4();
    final db = await AppDatabase.instance.database;

    // Save locally first — always tagged with the active company
    await db.insert('products', {
      'id': newId,
      'company_id': companyId,
      'name': name,
      'category': category,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'quantity': quantity,
      'minimum_stock': minimumStock,
      'barcode': barcode,
      'expiration_date': expirationDate != null ? _dateOnly(expirationDate) : null,
      'size': size,
      'color': color,
      'brand': brand,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Refresh memory state immediately
    final localList = await _fetchFromLocal();
    if (mounted) {
      state = AsyncValue.data(localList);
    }

    // Try posting to API in background / queue
    try {
      final client = _ref.read(apiClientProvider);
      await client.post('/products', body: {
        'name': name,
        'category': category,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'quantity': quantity,
        'minimumStock': minimumStock,
        if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
        if (expirationDate != null) 'expirationDate': _dateOnly(expirationDate),
        if (size != null && size.isNotEmpty) 'size': size,
        if (color != null && color.isNotEmpty) 'color': color,
        if (brand != null && brand.isNotEmpty) 'brand': brand,
      });
      await load();
    } catch (_) {
      // Offline: Enqueue for sync
      await _ref.read(syncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: newId,
        entityType: 'product',
        entityId: newId,
        operationType: 'CREATE',
        payload: {
          'name': name,
          'category': category,
          'purchasePrice': purchasePrice,
          'sellingPrice': sellingPrice,
          'quantity': quantity,
          'minimumStock': minimumStock,
          if (barcode != null) 'barcode': barcode,
          if (expirationDate != null) 'expirationDate': _dateOnly(expirationDate),
          if (size != null) 'size': size,
          if (color != null) 'color': color,
          if (brand != null) 'brand': brand,
        },
      );
    }
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> updateProductImage(String id, String imageUrl) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    // Scoped by company_id to prevent cross-account updates
    await db.update(
      'products',
      {'image_url': imageUrl},
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
    final localList = await _fetchFromLocal();
    state = AsyncValue.data(localList);

    try {
      final client = _ref.read(apiClientProvider);
      await client.put('/products/$id', body: {'imageUrl': imageUrl});
    } catch (_) {}
  }

  Future<void> updateProduct(
    String id, {
    String? name,
    String? category,
    String? barcode,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    int? minimumStock,
    DateTime? expirationDate,
    String? size,
    String? color,
    String? brand,
    String? imageUrl,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (category != null) updates['category'] = category;
    if (barcode != null) updates['barcode'] = barcode;
    if (purchasePrice != null) updates['purchase_price'] = purchasePrice;
    if (sellingPrice != null) updates['selling_price'] = sellingPrice;
    if (quantity != null) updates['quantity'] = quantity;
    if (minimumStock != null) updates['minimum_stock'] = minimumStock;
    if (expirationDate != null) updates['expiration_date'] = _dateOnly(expirationDate);
    if (size != null) updates['size'] = size;
    if (color != null) updates['color'] = color;
    if (brand != null) updates['brand'] = brand;
    if (imageUrl != null) updates['image_url'] = imageUrl;

    if (updates.isNotEmpty) {
      // Scoped by company_id — cannot accidentally update another company's product
      await db.update(
        'products',
        updates,
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );
      final localList = await _fetchFromLocal();
      state = AsyncValue.data(localList);
    }

    try {
      final client = _ref.read(apiClientProvider);
      await client.put('/products/$id', body: {
        if (name != null) 'name': name,
        if (category != null) 'category': category,
        if (barcode != null) 'barcode': barcode,
        if (purchasePrice != null) 'purchasePrice': purchasePrice,
        if (sellingPrice != null) 'sellingPrice': sellingPrice,
        if (quantity != null) 'quantity': quantity,
        if (minimumStock != null) 'minimumStock': minimumStock,
        if (expirationDate != null) 'expirationDate': _dateOnly(expirationDate),
        if (size != null) 'size': size,
        if (color != null) 'color': color,
        if (brand != null) 'brand': brand,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
    } catch (_) {}
  }

  Future<void> deleteProduct(String id) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    // Scoped by company_id — cannot delete another company's product
    await db.delete(
      'products',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
    final localList = await _fetchFromLocal();
    state = AsyncValue.data(localList);

    try {
      final client = _ref.read(apiClientProvider);
      await client.delete('/products/$id');
    } catch (_) {}
  }

  Product? findById(String id) {
    return state.maybeWhen(
      data: (products) {
        for (final p in products) {
          if (p.id == id) return p;
        }
        return null;
      },
      orElse: () => null,
    );
  }

  Future<Product?> findByBarcode(String barcode) async {
    final companyId = _companyId;
    if (companyId == null) return null;

    // 1. Check in-memory list first (already scoped to this company)
    final memoryMatch = state.maybeWhen(
      data: (products) {
        for (final p in products) {
          if (p.barcode != null && p.barcode == barcode) return p;
        }
        return null;
      },
      orElse: () => null,
    );
    if (memoryMatch != null) return memoryMatch;

    // 2. Check local SQLite database (indexed, works 100% offline)
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'products',
        where: 'barcode = ? AND company_id = ?',
        whereArgs: [barcode, companyId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return Product.fromJson(rows.first);
      }
    } catch (_) {}

    // 3. Fallback to API if online
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/products/barcode/$barcode');
      final data = response['data'];
      if (data == null) return null;
      final p = Product.fromJson(data as Map<String, dynamic>);
      await _upsertToLocal([p]);
      return p;
    } catch (_) {
      return null;
    }
  }
}

final productsRepositoryProvider =
    StateNotifierProvider.autoDispose<ProductsRepository, AsyncValue<List<Product>>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return ProductsRepository(ref);
  },
);

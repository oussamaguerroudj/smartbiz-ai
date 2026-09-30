import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/product.dart';

/// Real HTTP-backed Products repository (Phase 5 wiring). Replaces the
/// Phase 4 in-memory version — same public shape where reasonable
/// (addProduct, findById) so the screens barely had to change, but
/// state is now AsyncValue<List<Product>> instead of a plain List,
/// since network calls can be loading/error, not just instant.
///
/// Single source of truth principle: after any mutation (add/update),
/// this re-fetches the full list from the server rather than
/// optimistically patching local state — guarantees the UI never
/// silently drifts from what the backend actually has.
class ProductsRepository extends StateNotifier<AsyncValue<List<Product>>> {
  ProductsRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load({String? search}) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get(
        '/products',
        query: (search != null && search.isNotEmpty) ? {'search': search} : null,
      );
      final products = (response['data'] as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addProduct({
    required String name,
    required String category,
    required double purchasePrice,
    required double sellingPrice,
    required int quantity,
    int minimumStock = 5,
    String? barcode,
    // Pharmacy (Ch. 15) — nullable, only ever sent when the caller
    // (Add Product form / AI Scan review) actually collected one.
    DateTime? expirationDate,
    // Clothing (Ch. 18) — nullable, same rule as expirationDate above.
    String? size,
    String? color,
    String? brand,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/products', body: {
      'name': name,
      'category': category,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'minimumStock': minimumStock,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      // Backend expects a plain DATE string (migration 006,
      // products.repository.create) — the time-of-day component is
      // meaningless for an expiration date, so it's stripped here.
      if (expirationDate != null)
        'expirationDate': _dateOnly(expirationDate),
      if (size != null && size.isNotEmpty) 'size': size,
      if (color != null && color.isNotEmpty) 'color': color,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
    });
    await load();
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Ch. 17/18 — saves an already-uploaded image
  /// (ImagesRepository.uploadImage(namespace: 'products')) onto this
  /// product via the existing PUT /products/:id endpoint (already
  /// supports partial updates via COALESCE — see
  /// products.repository.update).
  Future<void> updateProductImage(String id, String imageUrl) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/products/$id', body: {'imageUrl': imageUrl});
    await load();
  }

  /// Generic Edit Product save (Phase 2 finding — previously only the
  /// image could be updated from the app). Backend's PUT /products/:id
  /// already supports a full partial update via COALESCE for every one
  /// of these columns (products.repository.js `update`) — this was
  /// simply never called with anything but imageUrl from the client
  /// side until now. Every parameter is optional/nullable and only
  /// included in the request body when non-null, so calling this with
  /// just the fields that actually changed never clobbers the rest
  /// (COALESCE on the server keeps whatever wasn't sent).
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
    await load();
  }

  Future<void> deleteProduct(String id) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/products/$id');
    await load();
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

  /// Used by the barcode-scan buttons on the Sales/Stock pages. Checks
  /// the already-loaded list first (instant, no network) — if that list
  /// happens to be filtered (e.g. an active search on the Stock page)
  /// or just hasn't loaded a product added on another device yet, it
  /// falls back to a direct server lookup before concluding there's no
  /// match, rather than saying "not found" while the product genuinely
  /// exists.
  Future<Product?> findByBarcode(String barcode) async {
    final local = state.maybeWhen(
      data: (products) {
        for (final p in products) {
          if (p.barcode != null && p.barcode == barcode) return p;
        }
        return null;
      },
      orElse: () => null,
    );
    if (local != null) return local;

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get(
        '/products/barcode/$barcode',
      );
      final data = response['data'];
      if (data == null) return null;
      return Product.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      // Network hiccup or no match server-side either — either way,
      // from the scan button's point of view this just means "not
      // found", not a hard error worth surfacing separately.
      return null;
    }
  }
}

final productsRepositoryProvider =
    StateNotifierProvider.autoDispose<ProductsRepository, AsyncValue<List<Product>>>(
  (ref) => ProductsRepository(ref),
);

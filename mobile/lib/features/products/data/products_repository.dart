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
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/products', body: {
      'name': name,
      'category': category,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'minimumStock': minimumStock,
    });
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
}

final productsRepositoryProvider =
    StateNotifierProvider<ProductsRepository, AsyncValue<List<Product>>>(
  (ref) => ProductsRepository(ref),
);

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// Ch. 17/18 "Product Images  -  All Business Types". Thin wrapper around
/// the shared backend images module (POST /images, GET /images/file)  - 
/// one client-side entry point reused by every products/items screen
/// instead of duplicating base64-encode-and-post in each one.
class ImagesRepository {
  ImagesRepository(this._ref);
  final Ref _ref;

  /// [namespace] must match one the backend allows: 'products',
  /// 'restaurant-menu', 'restaurant-inventory'. Returns the storage key
  /// to save on the owning record (products.image_url,
  /// restaurant_menu_items.image_url, restaurant_inventory_items.image_url)
  ///  -  never a directly-usable URL; fetching it back always goes
  /// through [fetchImageBytes] so the company-ownership check on the
  /// way out always runs.
  Future<String> uploadImage({
    required String namespace,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/images', body: {
      'namespace': namespace,
      'fileBase64': base64Encode(bytes),
      'mimeType': mimeType,
    });
    return (response['data'] as Map<String, dynamic>)['imageUrl'] as String;
  }

  Future<Uint8List> fetchImageBytes(String storageKey) async {
    final client = _ref.read(apiClientProvider);
    return client.getBytes('/images/file', query: {'key': storageKey});
  }
}

final imagesRepositoryProvider = Provider<ImagesRepository>((ref) => ImagesRepository(ref));

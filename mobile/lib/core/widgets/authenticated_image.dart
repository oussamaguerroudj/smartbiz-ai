import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/images_repository.dart';

/// Ch. 17/18 — renders an image stored via ImagesRepository. Not a
/// plain Image.network: the backend requires the caller's auth token
/// (GET /images/file is behind authMiddleware, company-scoped), so
/// bytes are fetched the same way every other authenticated binary in
/// this app is (getBytes) and cached per storageKey for the life of
/// the provider container, rather than re-downloading on every rebuild.
final _imageBytesProvider = FutureProvider.autoDispose.family((ref, String storageKey) {
  ref.keepAlive();
  return ref.read(imagesRepositoryProvider).fetchImageBytes(storageKey);
});

class AuthenticatedImage extends ConsumerWidget {
  const AuthenticatedImage({
    super.key,
    required this.storageKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String storageKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesAsync = ref.watch(_imageBytesProvider(storageKey));

    final child = bytesAsync.when(
      data: (bytes) => Image.memory(bytes, width: width, height: height, fit: fit),
      loading: () => SizedBox(
        width: width,
        height: height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => SizedBox(
        width: width,
        height: height,
        child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
      ),
    );

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

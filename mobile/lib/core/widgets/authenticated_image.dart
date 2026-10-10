import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/images_repository.dart';
import 'file_image_loader.dart';

/// Ch. 17/18 — renders an image stored via ImagesRepository, network URL,
/// or local file path. When a storage key is passed, the backend requires
/// the caller's auth token (GET /images/file is behind authMiddleware,
/// company-scoped), so bytes are fetched via fetchImageBytes and cached.
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
    this.errorWidget,
    this.loadingWidget,
  });

  final String storageKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child;
    final trimmedKey = storageKey.trim();

    if (trimmedKey.startsWith('http://') || trimmedKey.startsWith('https://')) {
      child = Image.network(
        trimmedKey,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return loadingWidget ??
              SizedBox(
                width: width,
                height: height,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ??
              SizedBox(
                width: width,
                height: height,
                child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
              );
        },
      );
    } else if (!kIsWeb &&
        (trimmedKey.startsWith('/') || trimmedKey.contains(r':\') || trimmedKey.startsWith('file:'))) {
      final filePath =
          trimmedKey.startsWith('file://') ? trimmedKey.replaceFirst('file://', '') : trimmedKey;
      child = buildFileImage(
        filePath: filePath,
        width: width,
        height: height,
        fit: fit,
        errorWidget: errorWidget ??
            SizedBox(
              width: width,
              height: height,
              child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
            ),
      );
    } else {
      final bytesAsync = ref.watch(_imageBytesProvider(trimmedKey));

      child = bytesAsync.when(
        data: (bytes) => Image.memory(bytes, width: width, height: height, fit: fit),
        loading: () =>
            loadingWidget ??
            SizedBox(
              width: width,
              height: height,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        error: (_, __) =>
            errorWidget ??
            SizedBox(
              width: width,
              height: height,
              child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
            ),
      );
    }

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}


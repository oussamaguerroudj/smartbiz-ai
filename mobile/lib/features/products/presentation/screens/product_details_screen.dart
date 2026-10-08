import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/authenticated_image.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/images_repository.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';
import '../../../../l10n/app_localizations.dart';
import 'edit_product_screen.dart';

/// Product Details  -  Spec Ch. 10.3 with Edit and Delete support.
class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return productsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(body: Center(child: Text(l10n.errorPrefix(err)))),
      data: (products) {
        Product? product;
        for (final p in products) {
          if (p.id == productId) {
            product = p;
            break;
          }
        }
        if (product == null) {
          return Scaffold(body: Center(child: Text(l10n.productNotFound)));
        }
        return _ProductDetailsView(product: product);
      },
    );
  }
}

class _ProductDetailsView extends ConsumerWidget {
  const _ProductDetailsView({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EditProductScreen(product: product)),
              );
            },
          ),
          IconButton(
            tooltip: l10n.deleteProductTitle,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.deleteProductTitle),
                  content: Text(l10n.deleteConfirmMessage(product.name)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                try {
                  await ref.read(productsRepositoryProvider.notifier).deleteProduct(product.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          _ProductPhoto(product: product),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l10n.inStockLabel,
                  value: '${product.quantity}',
                  color: product.isOutOfStock
                      ? AppColors.stockOut
                      : product.isLowStock
                          ? AppColors.stockLow
                          : AppColors.stockHealthy,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatCard(
                  label: l10n.marginLabel,
                  value: '${product.marginPercent.toStringAsFixed(0)}%',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.pricingLabel, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.purchasePriceValue(product.purchasePrice.toStringAsFixed(0))),
                  Text(l10n.sellingPriceValue(product.sellingPrice.toStringAsFixed(0))),
                  Text(
                    l10n.profitPerUnitValue((product.sellingPrice - product.purchasePrice).toStringAsFixed(0)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.categoryLabelTitle, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(product.category),
                ],
              ),
            ),
          ),
          if (product.expirationDate != null || product.size != null || product.color != null || product.brand != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.expirationDate != null) ...[
                      Text(l10n.expirationDateLabel, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${product.expirationDate!.year.toString().padLeft(4, '0')}-'
                        '${product.expirationDate!.month.toString().padLeft(2, '0')}-${product.expirationDate!.day.toString().padLeft(2, '0')}',
                      ),
                      if (product.size != null || product.color != null || product.brand != null)
                        const SizedBox(height: AppSpacing.xs),
                    ],
                    if (product.size != null) ...[
                      Text('${l10n.sizeLabel}: ${product.size}'),
                      const SizedBox(height: 4),
                    ],
                    if (product.color != null) ...[
                      Text('${l10n.colorLabel}: ${product.color}'),
                      const SizedBox(height: 4),
                    ],
                    if (product.brand != null) Text('${l10n.brandLabel}: ${product.brand}'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductPhoto extends ConsumerWidget {
  const _ProductPhoto({required this.product});
  final Product product;

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType ?? 'image/jpeg';

    try {
      final imageUrl = await ref
          .read(imagesRepositoryProvider)
          .uploadImage(namespace: 'products', bytes: bytes, mimeType: mimeType);
      await ref.read(productsRepositoryProvider.notifier).updateProductImage(product.id, imageUrl);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _changePhoto(context, ref),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: product.imageUrl != null
            ? AuthenticatedImage(
                storageKey: product.imageUrl!,
                width: double.infinity,
                height: 160,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              )
            : const Center(child: Icon(Icons.add_a_photo_outlined, size: 32)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}

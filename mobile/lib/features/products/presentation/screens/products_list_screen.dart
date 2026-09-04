import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';
import 'add_product_screen.dart';
import 'product_details_screen.dart';

/// Products List — Spec Ch. 10.1. Now wired to real (local) data via
/// [productsRepositoryProvider] instead of static mock content.
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: productsAsync.maybeWhen(
          data: (products) => Text('Products · ${products.length}'),
          orElse: () => const Text('Products'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                setState(() => _query = v);
                // NOTE: fires one request per keystroke — fine for MVP
                // correctness; debouncing (e.g. 300ms) is a nice-to-have
                // follow-up, not required for this batch's scope.
                ref.read(productsRepositoryProvider.notifier).load(search: v);
              },
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => _ErrorRetry(
                message: err.toString(),
                onRetry: () => ref.read(productsRepositoryProvider.notifier).load(search: _query),
              ),
              data: (products) => products.isEmpty
                  ? const Center(child: Text('No products found'))
                  : RefreshIndicator(
                      onRefresh: () => ref.read(productsRepositoryProvider.notifier).load(search: _query),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, i) => _ProductRow(product: products[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 40, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final Product product;

  Color get _statusColor {
    if (product.isOutOfStock) return AppColors.stockOut;
    if (product.isLowStock) return AppColors.stockLow;
    return AppColors.stockHealthy;
  }

  String get _statusLabel {
    if (product.isOutOfStock) return 'Qty: 0 — Out of stock';
    if (product.isLowStock) return 'Qty: ${product.quantity} — Low stock';
    return 'Qty: ${product.quantity}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailsScreen(productId: product.id)),
      ),
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _statusColor.withValues(alpha: 0.15),
              foregroundColor: _statusColor,
              child: Text(product.name.substring(0, 1)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    _statusLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _statusColor),
                  ),
                ],
              ),
            ),
            Text(
              '${product.sellingPrice.toStringAsFixed(0)} DZD',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';

/// Product Details — Spec Ch. 10.3.
/// Sales-history mini-chart and stock-adjustment log are deferred to the
/// batch that builds Reports/Analytics aggregation (they need real sales
/// history, which now exists via SalesRepository — wiring lands next
/// batch to keep this one reviewable).
class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsRepositoryProvider);
    Product? product;
    for (final p in products) {
      if (p.id == productId) {
        product = p;
        break;
      }
    }

    if (product == null) {
      return const Scaffold(body: Center(child: Text('Product not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'In Stock',
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
                  label: 'Margin',
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
                  Text('Pricing',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                      'Purchase: ${product.purchasePrice.toStringAsFixed(0)} DZD'),
                  Text(
                      'Selling: ${product.sellingPrice.toStringAsFixed(0)} DZD'),
                  Text(
                    'Profit/unit: ${(product.sellingPrice - product.purchasePrice).toStringAsFixed(0)} DZD',
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
                  Text('Category',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(product.category),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.color});
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
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color)),
        ],
      ),
    );
  }
}

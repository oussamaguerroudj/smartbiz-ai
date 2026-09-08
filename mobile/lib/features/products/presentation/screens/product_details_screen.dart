import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';
import '../../../../l10n/app_localizations.dart';

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

class _ProductDetailsView extends StatelessWidget {
  const _ProductDetailsView({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
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
        ],
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

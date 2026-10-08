import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/widgets/barcode_scanner_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';
import '../widgets/universal_product_card.dart';
import 'add_product_screen.dart';
import 'product_details_screen.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';

/// Products List  -  Spec Ch. 10.1. Wired to real data via
/// [productsRepositoryProvider] and renders each product using the
/// universal [UniversalProductCard] component.
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _query = '';
  String? _selectedCategory;

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final product = await ref.read(productsRepositoryProvider.notifier).findByBarcode(code);
    if (!mounted) return;

    if (product != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailsScreen(productId: product.id)),
      );
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.barcodeNotFoundMessage(code)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.addAsNewProductAction),
          ),
        ],
      ),
    );

    if (shouldAdd == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddProductScreen(initialBarcode: code)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: productsAsync.maybeWhen(
          data: (products) => Text(l10n.productsTitleCount(products.length)),
          orElse: () => Text(l10n.productsTitle),
        ),
        actions: [
          IconButton(
            tooltip: l10n.scanInvoice,
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AiScannerScreen(mode: InvoiceScanMode.stock),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Scanner Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l10n.searchProductsHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      setState(() => _query = v);
                      ref.read(productsRepositoryProvider.notifier).load(search: v);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  child: IconButton(
                    tooltip: l10n.scanBarcodeTooltip,
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                    onPressed: _scanBarcode,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  child: IconButton(
                    tooltip: l10n.scanInvoice,
                    icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AiScannerScreen(mode: InvoiceScanMode.stock),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Products View
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => _ErrorRetry(
                message: err.toString(),
                onRetry: () => ref.read(productsRepositoryProvider.notifier).load(search: _query),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return Center(child: Text(l10n.noProductsFound));
                }

                // Extract unique categories for filtering
                final categories = <String>{};
                for (final p in products) {
                  final cat = p.category.trim();
                  if (cat.isNotEmpty && cat.toLowerCase() != 'uncategorized') {
                    categories.add(cat);
                  }
                }
                final sortedCategories = categories.toList()..sort();

                // Apply active category filter
                final displayedProducts = _selectedCategory == null
                    ? products
                    : products
                        .where((p) => p.category.trim().toLowerCase() == _selectedCategory!.toLowerCase())
                        .toList();

                return RefreshIndicator(
                  onRefresh: () => ref.read(productsRepositoryProvider.notifier).load(search: _query),
                  child: Column(
                    children: [
                      // Inventory Value Summary Card
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.info),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.inventoryValueLabel,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              Text(
                                '${products.fold<double>(0.0, (sum, p) => sum + (p.quantity > 0 ? (p.sellingPrice - p.purchasePrice) * p.quantity : 0.0)).toStringAsFixed(0)} DZD',
                                style: AppTypography.statValue(AppColors.info).copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Category Filter Chips Row (when multiple categories exist)
                      if (sortedCategories.isNotEmpty)
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(
                                    l10n.dashboardAllGood.contains('All') ? 'All' : 'All',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  selected: _selectedCategory == null,
                                  onSelected: (_) => setState(() => _selectedCategory = null),
                                ),
                              ),
                              for (final cat in sortedCategories)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _selectedCategory == cat ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    selected: _selectedCategory == cat,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedCategory = selected ? cat : null;
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // Responsive Product Cards List / Grid
                      Expanded(
                        child: displayedProducts.isEmpty
                            ? Center(child: Text(l10n.noProductsFound))
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  // Responsive: on wider screens (tablet/web), render a multi-column grid
                                  if (constraints.maxWidth >= 600) {
                                    final crossAxisCount = (constraints.maxWidth / 320).floor().clamp(2, 4);
                                    return GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.sm,
                                        AppSpacing.xs,
                                        AppSpacing.sm,
                                        AppSpacing.xl + AppSpacing.lg,
                                      ),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: AppSpacing.sm,
                                        mainAxisSpacing: AppSpacing.sm,
                                        mainAxisExtent: 260,
                                      ),
                                      itemCount: displayedProducts.length,
                                      itemBuilder: (context, i) => FadeSlideIn(
                                        delay: Duration(milliseconds: 20 * i.clamp(0, 15)),
                                        child: UniversalProductCard(
                                          product: displayedProducts[i],
                                        ),
                                      ),
                                    );
                                  }

                                  // Mobile layout: vertical list of rich product cards
                                  return ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.sm,
                                      AppSpacing.xs,
                                      AppSpacing.sm,
                                      AppSpacing.xl + AppSpacing.lg,
                                    ),
                                    itemCount: displayedProducts.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (context, i) => FadeSlideIn(
                                      delay: Duration(milliseconds: 20 * i.clamp(0, 15)),
                                      child: UniversalProductCard(
                                        product: displayedProducts[i],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: AppFab(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
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
            OutlinedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.retry)),
          ],
        ),
      ),
    );
  }
}

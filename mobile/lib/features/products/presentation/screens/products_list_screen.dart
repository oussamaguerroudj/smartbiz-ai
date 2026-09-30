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
import 'add_product_screen.dart';
import 'product_details_screen.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';

/// Products List — Spec Ch. 10.1. Now wired to real (local) data via
/// [productsRepositoryProvider] instead of static mock content.
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _query = '';

  Future<void> _scanBarcode(BuildContext context) async {
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

    // No existing product has this barcode — offer to add one straight
    // away instead of just saying "not found" and leaving the user to
    // retype the code by hand on the Add Product screen.
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
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
                      // NOTE: fires one request per keystroke — fine for MVP
                      // correctness; debouncing (e.g. 300ms) is a nice-to-have
                      // follow-up, not required for this batch's scope.
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
                    onPressed: () => _scanBarcode(context),
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
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => _ErrorRetry(
                message: err.toString(),
                onRetry: () => ref.read(productsRepositoryProvider.notifier).load(search: _query),
              ),
              data: (products) => products.isEmpty
                  ? Center(child: Text(l10n.noProductsFound))
                  : RefreshIndicator(
                      onRefresh: () => ref.read(productsRepositoryProvider.notifier).load(search: _query),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
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
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.sm,
                                AppSpacing.xs,
                                AppSpacing.sm,
                                AppSpacing.xl + AppSpacing.lg,
                              ),
                              itemCount: products.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                              itemBuilder: (context, i) => FadeSlideIn(
                                delay: Duration(milliseconds: 30 * i),
                                child: _ProductRow(product: products[i]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final Product product;

  Color get _statusColor {
    if (product.isOutOfStock) return AppColors.stockOut;
    if (product.isLowStock) return AppColors.stockLow;
    return AppColors.stockHealthy;
  }

  String _statusLabel(AppLocalizations l10n) {
    if (product.isOutOfStock) return l10n.qtyOutOfStock;
    if (product.isLowStock) return l10n.qtyLowStock(product.quantity);
    return l10n.qtyOnly(product.quantity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          boxShadow: AppSpacing.cardElevation,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    _statusLabel(l10n),
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

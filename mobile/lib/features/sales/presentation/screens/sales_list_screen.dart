import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';
import '../screens/create_sale_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';

/// Sales List — Spec Ch. 11.1. Real API-backed (Phase 5 wiring):
/// GET /sales, including item_count and invoice_number directly on
/// each row (backend query added in this batch) so no extra
/// cross-repository joins are needed client-side anymore.
class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSales),
        actions: [
          IconButton(
            tooltip: l10n.scanInvoice,
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AiScannerScreen(mode: InvoiceScanMode.sales),
              ),
            ),
          ),
        ],
      ),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorPrefix(err)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(salesRepositoryProvider.notifier).load(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (sales) => sales.isEmpty
            ? Center(child: Text(l10n.salesEmptyState))
            : RefreshIndicator(
                onRefresh: () => ref.read(salesRepositoryProvider.notifier).load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final sale = sales[i];
                    final isUnpaid = sale.paymentStatus == PaymentStatus.unpaid;
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 35 * i),
                      child: InkWell(
                        onTap: sale.invoiceId != null
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailsScreen(invoiceId: sale.invoiceId!),
                                  ),
                                )
                            : null,
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
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sale.invoiceNumber ?? l10n.saleNumberFallback(sale.id),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      l10n.saleRowSubtitle(sale.customerName ?? l10n.walkInCustomer, sale.itemCount),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${sale.total.toStringAsFixed(0)} DZD',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: isUnpaid ? AppColors.danger : AppColors.primary,
                                    ),
                              ),
                              if (sale.invoiceId != null) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
        ),
      ),
    );
  }
}

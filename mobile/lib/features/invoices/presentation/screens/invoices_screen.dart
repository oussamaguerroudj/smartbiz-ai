import '../../../../core/widgets/directional_chevron.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/invoices_repository.dart';
import '../../domain/invoice.dart';
import '../../../sales/domain/sale.dart';

/// Invoices — Spec Ch. 13/14. Real API-backed: reads from GET /invoices,
/// GET /invoices/:id, and streams binary PDF via GET /invoices/:id/pdf.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoicesTitle)),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (invoices) => invoices.isEmpty
            ? Center(child: Text(l10n.noInvoicesYet))
            : RefreshIndicator(
                onRefresh: () => ref.read(invoicesRepositoryProvider.notifier).load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final invoice = invoices[i];
                    final isUnpaid = invoice.status == PaymentStatus.unpaid;
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 40 * i),
                      child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailsScreen(invoiceId: invoice.id),
                        ),
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
                                    invoice.invoiceNumber,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    invoice.customerName ?? l10n.walkInCustomer,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${invoice.total.toStringAsFixed(0)} DZD',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: isUnpaid ? AppColors.danger : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                StatusPill(
                                  label: isUnpaid ? l10n.statusUnpaid : l10n.statusPaid,
                                  tone: isUnpaid ? PillTone.danger : PillTone.brand,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const ForwardChevron(size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class InvoiceDetailsScreen extends ConsumerWidget {
  const InvoiceDetailsScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(invoiceDetailsProvider(invoiceId));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(detailsAsync.valueOrNull?.invoiceNumber ?? l10n.invoiceFallback)),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (invoice) => ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.billTo, style: Theme.of(context).textTheme.labelLarge),
                    Text(invoice.customerName ?? l10n.walkInCustomer),
                    const Divider(height: AppSpacing.md),
                    Text(l10n.itemsLabel, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    ...invoice.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                l10n.lineItemLabel(item.productName, item.quantity),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${item.lineTotal.toStringAsFixed(0)} DZD',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.totalLabel, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${invoice.total.toStringAsFixed(0)} DZD',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await Printing.layoutPdf(
                          onLayout: (_) => ref
                              .read(invoicesRepositoryProvider.notifier)
                              .fetchInvoicePdf(invoice.id),
                          name: 'invoice_${invoice.invoiceNumber}.pdf',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.exportAsPdf),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final bytes = await ref
                            .read(invoicesRepositoryProvider.notifier)
                            .fetchInvoicePdf(invoice.id);
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: 'invoice_${invoice.invoiceNumber}.pdf',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.shareViaWhatsapp),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

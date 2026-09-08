import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/invoices_repository.dart';
import '../../domain/invoice.dart';
import '../../../sales/domain/sale.dart';

/// Invoices — Spec Ch. 13/14. Real API-backed (Phase 5 wiring): reads
/// from GET /invoices / GET /invoices/:id. PDF export / WhatsApp share
/// still stubbed — the backend endpoint exists but returns 501
/// (NOT_IMPLEMENTED) until a PDF library is wired in a future batch.
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(invoice.invoiceNumber,
                                      style: Theme.of(context).textTheme.titleMedium),
                                  Text(invoice.customerName ?? l10n.walkInCustomer),
                                ],
                              ),
                            ),
                            StatusPill(
                              label: isUnpaid ? l10n.statusUnpaid : l10n.statusPaid,
                              tone: isUnpaid ? PillTone.danger : PillTone.brand,
                            ),
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
                            Text(l10n.lineItemLabel(item.productName, item.quantity)),
                            Text('${item.lineTotal.toStringAsFixed(0)} DZD'),
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
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.pdfExportNotImplemented),
                ),
              ),
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n.shareViaWhatsapp),
            ),
          ],
        ),
      ),
    );
  }
}

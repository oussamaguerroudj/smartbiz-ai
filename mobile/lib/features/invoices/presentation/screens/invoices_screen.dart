import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/sale.dart';

/// Invoices — Spec Ch. 13/14. Reads from InvoicesRepository/SalesRepository
/// (populated automatically whenever a sale is confirmed — Phase 4 Sales
/// batch). PDF export / WhatsApp share are stubbed with a snackbar: real
/// PDF generation needs a backend endpoint (`GET /invoices/:id/pdf`,
/// Phase 1 §12) that doesn't exist until Phase 5.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesRepositoryProvider);
    final sales = ref.watch(salesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: invoices.isEmpty
          ? const Center(child: Text('No invoices yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: invoices.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final invoice = invoices[i];
                Sale? sale;
                for (final s in sales) {
                  if (s.id == invoice.saleId) {
                    sale = s;
                    break;
                  }
                }
                final isUnpaid = invoice.status == PaymentStatus.unpaid;
                return InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          InvoiceDetailsScreen(invoiceId: invoice.id),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invoice.invoiceNumber,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(sale?.customerName ?? 'Walk-in'),
                            ],
                          ),
                        ),
                        Text(
                          isUnpaid ? 'Unpaid' : 'Paid',
                          style: TextStyle(
                            color:
                                isUnpaid ? AppColors.danger : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class InvoiceDetailsScreen extends ConsumerWidget {
  const InvoiceDetailsScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesRepositoryProvider);
    final sales = ref.watch(salesRepositoryProvider);

    Invoice? invoice;
    for (final inv in invoices) {
      if (inv.id == invoiceId) {
        invoice = inv;
        break;
      }
    }
    if (invoice == null) {
      return const Scaffold(body: Center(child: Text('Invoice not found')));
    }

    Sale? sale;
    for (final s in sales) {
      if (s.id == invoice.saleId) {
        sale = s;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(invoice.invoiceNumber)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill To',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(sale?.customerName ?? 'Walk-in'),
                  const Divider(height: AppSpacing.md),
                  Text('Items', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  ...?sale?.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.productName} × ${item.quantity}'),
                          Text('${item.lineTotal.toStringAsFixed(0)} DZD'),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${sale?.total.toStringAsFixed(0) ?? "0"} DZD',
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
              const SnackBar(
                content: Text(
                    'PDF export requires the backend API — lands in Phase 5'),
              ),
            ),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share via WhatsApp'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';
import 'create_sale_screen.dart';

/// Sales List — Spec Ch. 11.1. Wired to [salesRepositoryProvider].
class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesRepositoryProvider);
    final invoices = ref.watch(invoicesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: sales.isEmpty
          ? const Center(child: Text('No sales yet — tap + to record one'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: sales.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final sale = sales[i];
                Invoice? invoice;
                for (final inv in invoices) {
                  if (inv.saleId == sale.id) {
                    invoice = inv;
                    break;
                  }
                }
                final isUnpaid = sale.paymentStatus == PaymentStatus.unpaid;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice?.invoiceNumber ?? 'Sale #${sale.id}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${sale.customerName ?? "Walk-in"} · ${sale.items.length} item(s)',
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
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'sales_fab',
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

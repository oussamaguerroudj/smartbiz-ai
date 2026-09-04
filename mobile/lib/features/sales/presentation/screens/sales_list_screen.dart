import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';
import 'create_sale_screen.dart';

/// Sales List — Spec Ch. 11.1. Real API-backed (Phase 5 wiring):
/// GET /sales, including item_count and invoice_number directly on
/// each row (backend query added in this batch) so no extra
/// cross-repository joins are needed client-side anymore.
class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $err'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.read(salesRepositoryProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (sales) => sales.isEmpty
            ? const Center(child: Text('No sales yet — tap + to record one'))
            : RefreshIndicator(
                onRefresh: () => ref.read(salesRepositoryProvider.notifier).load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final sale = sales[i];
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
                                  sale.invoiceNumber ?? 'Sale #${sale.id}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '${sale.customerName ?? "Walk-in"} · ${sale.itemCount} item(s)',
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
              ),
      ),
      floatingActionButton: FloatingActionButton(heroTag: 'sales_fab',
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

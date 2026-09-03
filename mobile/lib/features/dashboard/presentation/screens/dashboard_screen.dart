import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../products/data/products_repository.dart';
import '../../../sales/data/sales_repository.dart';

/// Dashboard — Spec Ch. 9. Now reads real (local) data from
/// ProductsRepository and SalesRepository instead of static placeholders.
/// Expenses KPI stays "—" until the Expenses feature is built in a later
/// Phase-4 batch — showing a fabricated number would violate the
/// "AI/UI must never invent financial figures" principle even for a
/// non-AI screen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsRepositoryProvider);
    final sales = ref.watch(salesRepositoryProvider);

    final todaySales = sales.where((s) => _isToday(s.soldAt)).toList();
    final todayRevenue = todaySales.fold<double>(0, (sum, s) => sum + s.total);
    final todayProfit =
        todaySales.fold<double>(0, (sum, s) => sum + s.grossProfit);
    final lowStock =
        products.where((p) => p.isLowStock || p.isOutOfStock).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _KpiCard(
                    label: 'Today Revenue',
                    value: '${todayRevenue.toStringAsFixed(0)} DZD',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const _KpiCard(
                      label: 'Expenses', value: '—', color: AppColors.danger),
                  const SizedBox(width: AppSpacing.xs),
                  _KpiCard(
                    label: 'Profit',
                    value: '${todayProfit.toStringAsFixed(0)} DZD',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                    child: _MiniKpi(
                        label: 'Sales', value: '${todaySales.length}')),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _MiniKpi(
                        label: 'Low Stock', value: '${lowStock.length}')),
                const SizedBox(width: AppSpacing.xs),
                const Expanded(
                    child: _MiniKpi(label: 'Unpaid Inv.', value: '—')),
              ],
            ),
            if (lowStock.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Text(
                  '${lowStock.length} product(s) are low in stock',
                  style: const TextStyle(color: AppColors.primaryDark),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Sales',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    if (sales.isEmpty)
                      const Text('No sales recorded yet.')
                    else
                      ...sales.take(3).map(
                            (s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '${s.customerName ?? "Walk-in"} · ${s.items.length} item(s)'),
                                  Text('${s.total.toStringAsFixed(0)} DZD'),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
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
          const Spacer(),
          Text(
            value,
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.label, required this.value});

  final String label;
  final String value;

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
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

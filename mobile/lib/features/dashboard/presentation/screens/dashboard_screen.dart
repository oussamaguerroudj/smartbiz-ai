import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/dashboard_repository.dart';

/// Dashboard — Spec Ch. 9. Real API-backed (Phase 5 wiring): every KPI
/// comes straight from GET /dashboard (verified end-to-end in testing —
/// revenue/profit/low-stock/unpaid-invoice counts all matched hand
/// calculations exactly).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardRepositoryProvider.notifier).load(),
          ),
        ],
      ),
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $err'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.read(dashboardRepositoryProvider.notifier).load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (dashboard) => RefreshIndicator(
            onRefresh: () => ref.read(dashboardRepositoryProvider.notifier).load(),
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
                        value: '${dashboard.todayRevenue.toStringAsFixed(0)} DZD',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _KpiCard(
                        label: 'Expenses',
                        value: '${dashboard.todayExpenses.toStringAsFixed(0)} DZD',
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _KpiCard(
                        label: 'Profit',
                        value: '${dashboard.todayProfit.toStringAsFixed(0)} DZD',
                        color: dashboard.todayProfit >= 0 ? AppColors.primary : AppColors.danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: _MiniKpi(label: 'Sales', value: '${dashboard.salesCount}')),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: _MiniKpi(label: 'Low Stock', value: '${dashboard.lowStockCount}')),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _MiniKpi(label: 'Unpaid Inv.', value: '${dashboard.unpaidInvoicesCount}'),
                    ),
                  ],
                ),
                if (dashboard.lowStockCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Text(
                      '${dashboard.lowStockCount} product(s) are low in stock',
                      style: const TextStyle(color: AppColors.primaryDark),
                    ),
                  ),
                ],
                if (dashboard.upcomingAppointmentsCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: AppColors.info),
                    ),
                    child: Text('${dashboard.upcomingAppointmentsCount} upcoming appointment(s)'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.color});

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
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

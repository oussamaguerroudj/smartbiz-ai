import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../sales/data/sales_repository.dart';

enum ReportPeriod { daily, weekly, monthly, yearly }

/// Reports — Spec Ch. 22. Real aggregation over SalesRepository /
/// ExpensesRepository (no invented figures). PDF/Excel export is stubbed
/// with a snackbar — needs the backend export endpoints (Phase 5/8).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.monthly;

  DateTime get _cutoff {
    final now = DateTime.now();
    return switch (_period) {
      ReportPeriod.daily => DateTime(now.year, now.month, now.day),
      ReportPeriod.weekly => now.subtract(const Duration(days: 7)),
      ReportPeriod.monthly => DateTime(now.year, now.month, 1),
      ReportPeriod.yearly => DateTime(now.year, 1, 1),
    };
  }

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesRepositoryProvider);
    final expenses = ref.watch(expensesRepositoryProvider);

    final periodSales = sales.where((s) => s.soldAt.isAfter(_cutoff)).toList();
    final periodExpenses =
        expenses.where((e) => e.date.isAfter(_cutoff)).toList();

    final revenue = periodSales.fold<double>(0, (sum, s) => sum + s.total);
    final expenseTotal =
        periodExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final profit = revenue - expenseTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(value: ReportPeriod.daily, label: Text('Daily')),
              ButtonSegment(value: ReportPeriod.weekly, label: Text('Weekly')),
              ButtonSegment(
                  value: ReportPeriod.monthly, label: Text('Monthly')),
              ButtonSegment(value: ReportPeriod.yearly, label: Text('Yearly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                  child: _Stat('Revenue', revenue.toStringAsFixed(0),
                      AppColors.primary)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: _Stat('Expenses', expenseTotal.toStringAsFixed(0),
                      AppColors.danger)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: _Stat(
                      'Profit', profit.toStringAsFixed(0), AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sales count',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('${periodSales.length} sale(s) in this period'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'PDF/Excel export requires the backend — Phase 5/8')),
            ),
            child: const Text('Export as PDF'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'PDF/Excel export requires the backend — Phase 5/8')),
            ),
            child: const Text('Export as Excel'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

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
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color)),
        ],
      ),
    );
  }
}

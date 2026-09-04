import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';

class TopProduct {
  TopProduct({required this.name, required this.unitsSold});
  final String name;
  final int unitsSold;

  factory TopProduct.fromJson(Map<String, dynamic> json) =>
      TopProduct(name: json['name'] as String, unitsSold: (json['units_sold'] as num).toInt());
}

class ReportData {
  ReportData({
    required this.revenue,
    required this.expenses,
    required this.netProfit,
    required this.grossProfit,
    required this.salesCount,
    required this.topProducts,
  });

  final double revenue;
  final double expenses;
  final double netProfit;
  final double grossProfit;
  final int salesCount;
  final List<TopProduct> topProducts;

  factory ReportData.fromJson(Map<String, dynamic> json) => ReportData(
        revenue: (json['revenue'] as num).toDouble(),
        expenses: (json['expenses'] as num).toDouble(),
        netProfit: (json['netProfit'] as num).toDouble(),
        grossProfit: (json['grossProfit'] as num).toDouble(),
        salesCount: json['salesCount'] as int,
        topProducts: (json['topProducts'] as List)
            .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// GET /reports?period=... — real API-backed (Phase 5 wiring), verified
/// end-to-end in Phase 5 testing (matched Dashboard's numbers exactly
/// for the same period, plus correct grossProfit/topProducts).
final reportProvider = FutureProvider.autoDispose.family<ReportData, String>((ref, period) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/reports', query: {'period': period});
  return ReportData.fromJson(response['data'] as Map<String, dynamic>);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = 'monthly';

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportProvider(_period));

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Daily')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ButtonSegment(value: 'yearly', label: Text('Yearly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          reportAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, st) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(child: Text('Error: $err')),
            ),
            data: (report) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Stat('Revenue', report.revenue.toStringAsFixed(0), AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _Stat('Expenses', report.expenses.toStringAsFixed(0), AppColors.danger),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _Stat(
                        'Net Profit',
                        report.netProfit.toStringAsFixed(0),
                        report.netProfit >= 0 ? AppColors.primary : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sales count', style: Theme.of(context).textTheme.titleMedium),
                        Text('${report.salesCount} sale(s) in this period'),
                      ],
                    ),
                  ),
                ),
                if (report.topProducts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Top Products', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...report.topProducts.map(
                            (p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [Text(p.name), Text('${p.unitsSold} sold')],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF/Excel export lands in a future batch')),
                  ),
                  child: const Text('Export as PDF'),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF/Excel export lands in a future batch')),
                  ),
                  child: const Text('Export as Excel'),
                ),
              ],
            ),
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
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

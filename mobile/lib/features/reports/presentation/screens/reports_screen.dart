import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/mini_bar_chart.dart';
import '../../../../core/widgets/futuristic_nav_bar.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../../../l10n/app_localizations.dart';

class TopProduct {
  TopProduct({required this.name, required this.unitsSold});
  final String name;
  final int unitsSold;

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        name: json['name'] as String,
        unitsSold: (json['units_sold'] as num).toInt(),
      );
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
/// end-to-end in Phase 5 testing.
final reportProvider =
    FutureProvider.autoDispose.family<ReportData, String>((ref, period) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get(
    '/reports',
    query: {'period': period},
  );
  return ReportData.fromJson(response['data'] as Map<String, dynamic>);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _periods = ['daily', 'weekly', 'monthly', 'yearly'];

  List<String> _periodLabels(AppLocalizations l10n) => [
    l10n.periodDaily,
    l10n.periodWeekly,
    l10n.periodMonthly,
    l10n.periodYearly,
  ];

  String _period = 'monthly';

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportProvider(_period));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
      ),
      bottomNavigationBar: FuturisticNavBar(
        currentIndex: 3,
        onTap: (_) => Navigator.of(context).pop(),

        // AI Assistant is handled by the same futuristic center button.
        onAiAssistant: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AiAssistantScreen(),
            ),
          );
        },

        items: const [
          PillNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
          ),
          PillNavItem(
            icon: Icons.point_of_sale_outlined,
            activeIcon: Icons.point_of_sale_rounded,
            label: 'Sales',
          ),
          PillNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: 'Inventory',
          ),
          PillNavItem(
            icon: Icons.more_horiz_rounded,
            activeIcon: Icons.more_horiz_rounded,
            label: 'More',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // Centered period selector.
          Center(
            child: PillTabs(
              labels: _periodLabels(l10n),
              selectedIndex: _periods.indexOf(_period),
              onChanged: (i) => setState(
                () => _period = _periods[i],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          reportAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, st) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: Text(l10n.errorPrefix(err)),
              ),
            ),
            data: (report) => Column(
              key: ValueKey(_period),
              children: [
                FadeSlideIn(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          'Revenue',
                          report.revenue,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _Stat(
                          'Expenses',
                          report.expenses,
                          AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _Stat(
                          'Net Profit',
                          report.netProfit,
                          report.netProfit >= 0
                              ? AppColors.info
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusCard),
                      boxShadow: AppSpacing.cardElevation,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales count',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${report.salesCount} sale(s) in this period',
                        ),
                      ],
                    ),
                  ),
                ),
                if (report.topProducts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 110),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCard),
                        boxShadow: AppSpacing.cardElevation,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Products',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          MiniBarChart(
                            values: _normalized(
                              report.topProducts
                                  .map(
                                    (p) => p.unitsSold.toDouble(),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...report.topProducts.map(
                            (p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${p.unitsSold} sold',
                                    style: AppTypography.bodyStrong(
                                      AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Column(
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.exportComingSoon,
                            ),
                          ),
                        ),
                        child: Text(l10n.exportAsPdf),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OutlinedButton(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.exportComingSoon,
                            ),
                          ),
                        ),
                        child: Text(l10n.exportAsExcel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<double> _normalized(List<double> values) {
    if (values.isEmpty) return values;

    final maxV = values.reduce(
      (a, b) => a > b ? a : b,
    );

    if (maxV <= 0) {
      return values.map((_) => 0.0).toList();
    }

    return values.map((v) => v / maxV).toList();
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
    this.label,
    this.value,
    this.color,
  );

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          AnimatedCounter(
            value: value,
            style: AppTypography.statValue(color),
          ),
        ],
      ),
    );
  }
}

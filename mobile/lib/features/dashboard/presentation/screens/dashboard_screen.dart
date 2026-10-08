import '../../../../core/widgets/directional_chevron.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../../core/widgets/mini_bar_chart.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';
import '../../../auth/data/companies_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/sale.dart';
import '../../../sales/presentation/screens/create_sale_screen.dart';
import '../../data/dashboard_repository.dart';
import '../widgets/dashboard_pages_section.dart';
import '../../../../l10n/app_localizations.dart';

/// Dashboard — Spec Ch. 9. Real API-backed (Phase 5 wiring): every KPI
/// comes straight from GET /dashboard, verified end-to-end.
///
/// This revision is a UI-matching pass against the approved reference
/// design image — no new repositories, providers, packages, or screens
/// were added; every value shown is either real data already available
/// elsewhere in the app, or a neutral (never fabricated) label. See the
/// per-section notes below for exactly which reference details were
/// matched with real data vs. deliberately left neutral rather than faked.

/// Page-level vertical rhythm for this screen only. The KPI row is drawn
/// as a [Positioned] card that intentionally floats over the tail of the
/// gradient header — that overlap is part of the approved visual design
/// and is kept as-is. What was broken was the *arithmetic* around it: the
/// header's old fixed bottom padding (56) was smaller than
/// `_kKpiCardHeight - _kKpiOverlap` (96 - 32 = 64), so the cards actually
/// overlapped the header title/icons instead of just the empty gradient
/// tail beneath them, and the "spacer" meant to reserve room for the
/// overhanging cards before the chart was a non-positioned Stack child
/// that never actually added height to the Stack, so the chart card had
/// no real clearance either. Both numbers below are now derived from the
/// same three constants instead of separate magic numbers, so the two
/// gaps (header→cards, cards→chart) can never drift out of sync again.
const double _kKpiCardHeight = 96;
const double _kKpiOverlap = 32;
const double _kKpiTopGap = AppSpacing.md;
const double _kKpiBottomGap = AppSpacing.md;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dashboardAsync = ref.watch(dashboardRepositoryProvider);
    final companyAsync = ref.watch(companyInfoProvider);

    final dashboard = dashboardAsync.valueOrNull ?? DashboardData.empty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardRepositoryProvider.notifier).load(),
        child: CustomScrollView(
            slivers: [
              // Header + KPI row are built as ONE sliver (a Stack, not two
              // separate slivers bridged with Transform.translate like
              // before). Overlapping content that way could get clipped
              // at the boundary between slivers; a single
              // Stack(clipBehavior: Clip.none) can never clip an
              // overlapping child, which is the standard, safe Flutter
              // pattern for a "card floats over header" layout.
              SliverToBoxAdapter(
                child: _DashboardHeader(
                  company: companyAsync.valueOrNull,
                  dashboard: dashboard,
                  onOpenReports: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReportsScreen(),
                    ),
                  ),
                  onOpenAiAssistant: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiAssistantScreen(),
                    ),
                  ),
                  onOpenNotifications: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                // Top inset = how far the KPI cards hang below the header
                // sliver's own box (_kKpiOverlap) + a real, deliberate gap
                // before the chart (_kKpiBottomGap).
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  _kKpiOverlap + _kKpiBottomGap,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: _SalesTrendCard(
                        salesAsync: ref.watch(
                          salesRepositoryProvider,
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 90),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                        ),
                        child: _InventoryValueCard(
                          value: dashboard.inventoryValue,
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 110),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                        ),
                        child: _LowStockAlert(
                          count: dashboard.lowStockCount,
                          productsAsync: ref.watch(
                            productsRepositoryProvider,
                          ),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.add_rounded,
                                  size: 20,
                                ),
                                label: Text(l10n.newSale),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CreateSaleScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: AppSpacing.xs,
                            ),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.document_scanner_outlined,
                                  size: 20,
                                ),
                                label: Text(l10n.scanInvoice),
                                onPressed: () => showScanInvoiceChooser(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Bottom sheet shown when the Dashboard's "Scan Invoice" button is
/// tapped — lets the user say up front whether the invoice they're
/// about to photograph is a SALE (money coming in, decreases stock) or
/// a STOCK/purchase invoice (goods coming in, increases stock), since
/// those are opposite inventory effects that can't be inferred from the
/// photo alone.
Future<void> showScanInvoiceChooser(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final mode = await showModalBottomSheet<InvoiceScanMode>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusCard)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.scanInvoiceChooserTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ScanChoiceTile(
                icon: Icons.point_of_sale_rounded,
                title: l10n.scanSalesInvoiceOption,
                subtitle: l10n.scanSalesInvoiceSubtitle,
                onTap: () => Navigator.of(sheetContext).pop(InvoiceScanMode.sales),
              ),
              const SizedBox(height: AppSpacing.xs),
              _ScanChoiceTile(
                icon: Icons.inventory_2_rounded,
                title: l10n.scanStockInvoiceOption,
                subtitle: l10n.scanStockInvoiceSubtitle,
                onTap: () => Navigator.of(sheetContext).pop(InvoiceScanMode.stock),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    ),
  );

  if (mode == null || !context.mounted) return;

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AiScannerScreen(mode: mode)),
  );
}

class _ScanChoiceTile extends StatelessWidget {
  const _ScanChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const ForwardChevron(),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.company,
    required this.dashboard,
    required this.onOpenReports,
    required this.onOpenAiAssistant,
    required this.onOpenNotifications,
  });

  final CompanyInfo? company;
  final DashboardData dashboard;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenAiAssistant;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GradientHero(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                _kKpiCardHeight - _kKpiOverlap + _kKpiTopGap,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.goodMorning,
                          style: AppTypography.body(
                            Colors.white.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          company == null
                              ? 'Dashboard'
                              : '${company!.name} · ${company!.businessType}',
                          style: AppTypography.screenTitle(
                            Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 1. Reports
                  IconButton(
                    icon: const Icon(
                      Icons.bar_chart_rounded,
                      color: Colors.white,
                    ),
                    tooltip: l10n.moreReports,
                    onPressed: onOpenReports,
                  ),

                  // 2. AI Assistant
                  IconButton(
                    icon: const Icon(
                      Icons.smart_toy_outlined,
                      color: Colors.white,
                    ),
                    tooltip: l10n.moreAiAssistant,
                    onPressed: onOpenAiAssistant,
                  ),

                  // 3. Notifications
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    tooltip: l10n.moreNotifications,
                    onPressed: onOpenNotifications,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          bottom: -_kKpiOverlap,
          child: FadeSlideIn(
            child: SizedBox(
              height: _kKpiCardHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: l10n.dashboardRevenue,
                      value: dashboard.todayRevenue,
                      color: AppColors.primary,
                      subtitle: l10n.dashboardTodayCurrency('DZD'),
                    ),
                  ),
                  const SizedBox(
                    width: AppSpacing.xs,
                  ),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.dashboardProfit,
                      value: dashboard.todayProfit,
                      color: dashboard.todayProfit >= 0
                          ? AppColors.info
                          : AppColors.danger,
                      subtitle: l10n.dashboardToday,
                    ),
                  ),
                  const SizedBox(
                    width: AppSpacing.xs,
                  ),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.dashboardLowStock,
                      value: dashboard.lowStockCount.toDouble(),
                      decimals: 0,
                      color: dashboard.lowStockCount > 0
                          ? AppColors.danger
                          : AppColors.primary,
                      subtitle: dashboard.lowStockCount > 0
                          ? l10n.dashboardNeedsReview
                          : l10n.dashboardAllGood,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.subtitle,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final Color color;
  final String subtitle;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(
          AppSpacing.radiusCard,
        ),
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
          const Spacer(),
          AnimatedCounter(
            value: value,
            decimals: decimals,
            style: AppTypography.statValue(color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.caption(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

enum _TrendRange {
  week,
  month,
  year,
}

class _SalesTrendCard extends StatefulWidget {
  const _SalesTrendCard({
    required this.salesAsync,
  });

  final AsyncValue<List<Sale>> salesAsync;

  @override
  State<_SalesTrendCard> createState() => _SalesTrendCardState();
}

class _SalesTrendCardState extends State<_SalesTrendCard> {
  _TrendRange _range = _TrendRange.week;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(
          AppSpacing.radiusCard,
        ),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.salesTrend,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PillTabs(
                  labels: [
                    l10n.rangeWeek,
                    l10n.rangeMonth,
                    l10n.rangeYear,
                  ],
                  selectedIndex: _range.index,
                  onChanged: (i) => setState(
                    () => _range = _TrendRange.values[i],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          widget.salesAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (err, st) => SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  l10n.couldNotLoadSalesTrend,
                  style: AppTypography.body(
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            data: (sales) => _buildChart(context, sales),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    List<Sale> sales,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();

    late final List<double> totals;
    late final List<String> labels;

    switch (_range) {
      case _TrendRange.week:
        final today = DateTime(
          now.year,
          now.month,
          now.day,
        );

        final days = List.generate(
          7,
          (i) => today.subtract(
            Duration(days: 6 - i),
          ),
        );

        totals = List<double>.filled(7, 0);

        for (final sale in sales) {
          final d = DateTime(
            sale.soldAt.year,
            sale.soldAt.month,
            sale.soldAt.day,
          );

          final idx = days.indexWhere(
            (x) => x == d,
          );

          if (idx != -1) {
            totals[idx] += (sale.margin ?? sale.total);
          }
        }

        const dayLabels = [
          'M',
          'T',
          'W',
          'T',
          'F',
          'S',
          'S',
        ];

        labels = days
            .map(
              (d) => dayLabels[d.weekday - 1],
            )
            .toList();

        break;

      case _TrendRange.month:
        final startOfThisWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(
          Duration(
            days: now.weekday - 1,
          ),
        );

        final weekStarts = List.generate(
          6,
          (i) => startOfThisWeek.subtract(
            Duration(days: 7 * (5 - i)),
          ),
        );

        totals = List<double>.filled(6, 0);

        for (final sale in sales) {
          final d = DateTime(
            sale.soldAt.year,
            sale.soldAt.month,
            sale.soldAt.day,
          );

          for (var i = 0; i < weekStarts.length; i++) {
            final weekEnd = weekStarts[i].add(
              const Duration(days: 7),
            );

            if (!d.isBefore(weekStarts[i]) && d.isBefore(weekEnd)) {
              totals[i] += (sale.margin ?? sale.total);
              break;
            }
          }
        }

        labels = List.generate(
          6,
          (i) => 'W${i + 1}',
        );

        break;

      case _TrendRange.year:
        final months = List.generate(
          6,
          (i) => DateTime(
            now.year,
            now.month - (5 - i),
          ),
        );

        totals = List<double>.filled(6, 0);

        for (final sale in sales) {
          for (var i = 0; i < months.length; i++) {
            if (sale.soldAt.year == months[i].year &&
                sale.soldAt.month == months[i].month) {
              totals[i] += (sale.margin ?? sale.total);
              break;
            }
          }
        }

        const monthLabels = [
          'J',
          'F',
          'M',
          'A',
          'M',
          'J',
          'J',
          'A',
          'S',
          'O',
          'N',
          'D',
        ];

        labels = months
            .map(
              (m) => monthLabels[m.month - 1],
            )
            .toList();

        break;
    }

    final maxTotal = totals.fold<double>(
      0,
      (m, v) => v > m ? v : m,
    );

    if (maxTotal <= 0) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            l10n.noSalesInPeriod,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final normalized = totals.map((v) => v / maxTotal).toList();

    return Column(
      children: [
        MiniBarChart(
          values: normalized,
          height: 90,
          gap: 8,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LowStockAlert extends StatelessWidget {
  const _LowStockAlert({
    required this.count,
    required this.productsAsync,
  });

  final int count;
  final AsyncValue<List<Product>> productsAsync;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    String detail = '';

    final products = productsAsync.valueOrNull;

    if (products != null) {
      final lowStockNames = products
          .where(
            (p) => p.isLowStock || p.isOutOfStock,
          )
          .map((p) => p.name)
          .toList();

      if (lowStockNames.isNotEmpty) {
        final shown = lowStockNames.take(2).join(', ');

        detail = ' — $shown${lowStockNames.length > 2 ? '…' : ''}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(
          alpha: 0.14,
        ),
        borderRadius: BorderRadius.circular(
          AppSpacing.radiusCard,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.circle,
              color: AppColors.warning,
              size: 8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count product${count == 1 ? '' : 's'} '
              '${count == 1 ? 'is' : 'are'} running low'
              '$detail',
              style: AppTypography.bodyStrong(
                const Color(0xFF8A5A10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryValueCard extends StatelessWidget {
  const _InventoryValueCard({
    required this.value,
  });

  final double value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(
          AppSpacing.radiusCard,
        ),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.info),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inventoryValueLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${value.toStringAsFixed(0)} DZD',
                  style: AppTypography.statValue(AppColors.info),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


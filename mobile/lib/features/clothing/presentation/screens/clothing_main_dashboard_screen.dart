import '../../../../core/widgets/directional_chevron.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../../auth/data/companies_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../products/presentation/screens/products_list_screen.dart';
import '../../../suppliers/presentation/screens/suppliers_screen.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../credit/presentation/screens/credit_screen.dart';
import '../../../products/data/products_repository.dart';
import '../widgets/clothing_product_card.dart';
import '../../data/clothing_repository.dart';
import '../../domain/clothing_models.dart';
import '../../../dashboard/presentation/widgets/dashboard_pages_section.dart';

/// Clothing Store specialization of the MAIN Dashboard tab (business-
/// specialization brief Ch. 18; SPECIALIZED_MODULES.md §3's documented
/// pattern, fifth vertical after Clinic, Restaurant, Pharmacy and
/// Supérette).
///
/// Like Pharmacy and Supérette, a clothing store does NOT get its own
/// tabs or More-menu items — `main_shell.dart` only swaps THIS screen
/// in for tab 0; tabs 1-2 (Sales/Inventory) and the full CORE More menu
/// already fit (Ch. 21: "reuse existing APIs") — a clothing store's
/// "Products" screen already shows Size/Color/Brand once set (migration
/// 020 added those columns to the CORE products table/form).
///
/// Deliberately NOT a new design: same GradientHero header, overlapping
/// KPI-card row, FadeSlideIn stagger and AnimatedCounter as every other
/// vertical's main dashboard — only the CONTENT changes: today's sales/
/// profit, stock alerts (with size/color/brand tags), a stock-by-
/// category breakdown (Ch. 18's own "Categories" ask), and outstanding
/// customer credit/debt, same as Supérette's dashboard.
final clothingDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.read(clothingRepositoryProvider).dashboard();
});

const double _kKpiCardHeight = 96;
const double _kKpiOverlap = 32;
const double _kKpiTopGap = AppSpacing.md;
const double _kKpiBottomGap = AppSpacing.md;

class ClothingMainDashboardScreen extends ConsumerWidget {
  const ClothingMainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(clothingDashboardProvider);
    final companyAsync = ref.watch(companyInfoProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.errorPrefix(err)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(clothingDashboardProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(clothingDashboardProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ClothingDashboardHeader(
                  company: companyAsync.valueOrNull,
                  stats: stats,
                  onOpenReports: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  ),
                  onOpenAiAssistant: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                  ),
                  onOpenNotifications: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  _kKpiOverlap + _kKpiBottomGap,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 30),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: DashboardPagesSection(),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ClothingMiniStat(
                              label: l10n.lowStockLabel,
                              value: stats.lowStockCount.toString(),
                              color: stats.lowStockCount > 0 ? AppColors.warning : AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _ClothingMiniStat(
                              label: l10n.customerDebtLabel,
                              value: '${stats.outstandingDebt.toStringAsFixed(0)} DZD',
                              color: stats.outstandingDebt > 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _ClothingMiniStat(
                              label: l10n.stockValueLabel,
                              value: '${stats.stockCostValue.toStringAsFixed(0)} DZD',
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 110),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _StockAlertsCard(stats: stats),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _CategoryBreakdownCard(stats: stats),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 170),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _CustomerDebtCard(stats: stats),
                      ),
                    ),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 185),
                      child: Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: _RecentClothingProductsCard(),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _ClothingQuickActions(),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClothingDashboardHeader extends StatelessWidget {
  const _ClothingDashboardHeader({
    required this.company,
    required this.stats,
    required this.onOpenReports,
    required this.onOpenAiAssistant,
    required this.onOpenNotifications,
  });

  final CompanyInfo? company;
  final ClothingDashboardStats stats;
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
                          style: AppTypography.body(Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          company == null ? l10n.storeDashboardTitle : '${company!.name} · ${company!.businessType}',
                          style: AppTypography.screenTitle(Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
                    tooltip: l10n.moreReports,
                    onPressed: onOpenReports,
                  ),
                  IconButton(
                    icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
                    tooltip: l10n.moreAiAssistant,
                    onPressed: onOpenAiAssistant,
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
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
                      label: l10n.todayRevenueLabel,
                      value: stats.todayRevenue,
                      color: AppColors.primary,
                      subtitle: l10n.kpiSubtitleDzdToday,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.todayProfitLabel,
                      value: stats.todayNetProfit,
                      color: AppColors.info,
                      subtitle: l10n.kpiSubtitleNetToday,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.transactionsLabel,
                      value: stats.transactionsToday.toDouble(),
                      decimals: 0,
                      color: AppColors.success,
                      subtitle: l10n.dashboardToday,
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

/// Same visual contract as every other vertical's private `_KpiCard` —
/// duplicated (file-private here too) rather than exposing internals.
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          AnimatedCounter(value: value, decimals: decimals, style: AppTypography.statValue(color)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.caption(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ClothingMiniStat extends StatelessWidget {
  const _ClothingMiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
              maxLines: 1,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Ch. 18's "Low-stock items" alert, with size/color/brand shown inline
/// when set — same "most important right now" role as Pharmacy's/
/// Supérette's Stock Alerts card.
class _StockAlertsCard extends StatelessWidget {
  const _StockAlertsCard({required this.stats});

  final ClothingDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.stockAlertsTitle, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const ForwardChevron(),
                tooltip: l10n.productsTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductsListScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (stats.lowStockProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.noStockAlertsMessage,
                style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            )
          else
            for (final p in stats.lowStockProducts.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.checkroom_outlined, color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.name} · ${p.quantity} left (min ${p.minimumStock})',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p.attributeSummary != null)
                            Text(
                              p.attributeSummary!,
                              style: AppTypography.caption(
                                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
}

/// Ch. 18's "Categories" — a compact stock-by-category breakdown
/// (e.g. Men/Women/Kids), reusing the same `category` column every
/// other vertical already has.
class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.stats});

  final ClothingDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Text(l10n.stockByCategoryTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (stats.stockByCategory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.noProductsYetMessage,
                style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            )
          else
            for (final c in stats.stockByCategory.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.category,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${c.unitsInStock} units · ${c.productCount} items',
                      style: AppTypography.caption(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Ch. 18's "Credit/customer debt" — same card as
/// SuperetteMainDashboardScreen's `_CustomerDebtCard`, duplicated
/// file-private here rather than shared, matching this codebase's
/// existing per-vertical-file convention.
class _CustomerDebtCard extends StatelessWidget {
  const _CustomerDebtCard({required this.stats});

  final ClothingDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.customerDebtTitle, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const ForwardChevron(),
                tooltip: l10n.creditPageTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreditScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (stats.topDebtors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.noOutstandingDebtMessage,
                style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            )
          else
            for (final d in stats.topDebtors.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${d.balanceDue.toStringAsFixed(0)} DZD',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentClothingProductsCard extends ConsumerWidget {
  const _RecentClothingProductsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(productsRepositoryProvider);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.clothingProductsTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductsListScreen()),
                ),
                child: Text(AppLocalizations.of(context)!.viewAllAction),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: Text(l10n.noClothingProductsMessage)),
                );
              }
              final displayProducts = products.take(4).toList();
              return Column(
                children: [
                  for (final p in displayProducts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: ClothingProductCard(product: p),
                    ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Ch. 18/14 — fast access to a clothing store's most important
/// actions.
class _ClothingQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.checkroom_outlined, size: 20),
            label: Text(l10n.productsTitle),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductsListScreen()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined, size: 20),
            label: Text(l10n.moreSuppliers),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SuppliersScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

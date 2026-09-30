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
import '../../../credit/presentation/screens/credit_screen.dart';
import '../../data/pharmacy_repository.dart';
import '../../domain/pharmacy_models.dart';

/// Pharmacy specialization of the MAIN Dashboard tab (business-
/// specialization brief Ch. 15; SPECIALIZED_MODULES.md §3/§11's
/// documented pattern, third vertical after Clinic and Restaurant).
///
/// Unlike Clinic/Restaurant, Pharmacy does NOT get its own tabs or
/// More-menu items — `main_shell.dart` only swaps THIS screen in for
/// tab 0; tabs 1-2 (Sales/Inventory) and the full CORE More menu
/// (Suppliers, Customers, Invoices, Reports, ...) already fit a
/// pharmacy's needs exactly as Ch. 21 intends ("reuse existing APIs"):
/// a pharmacy's "Products"/"Sales"/"Suppliers" ARE the CORE screens,
/// not a specialized reimplementation of them.
///
/// Deliberately NOT a new design: same GradientHero header, overlapping
/// KPI-card row, FadeSlideIn stagger and AnimatedCounter as
/// ClinicMainDashboardScreen / RestaurantMainDashboardScreen — only the
/// CONTENT changes: today's sales/profit, low-stock + expiry alerts,
/// and inventory value instead of a patient queue or an orders board.
final pharmacyDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.read(pharmacyRepositoryProvider).dashboard();
});

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const double _kKpiCardHeight = 96;
const double _kKpiOverlap = 32;
const double _kKpiTopGap = AppSpacing.md;
const double _kKpiBottomGap = AppSpacing.md;

class PharmacyMainDashboardScreen extends ConsumerWidget {
  const PharmacyMainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(pharmacyDashboardProvider);
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
                onPressed: () => ref.invalidate(pharmacyDashboardProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pharmacyDashboardProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _PharmacyDashboardHeader(
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
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PharmacyMiniStat(
                              label: l10n.lowStockLabel,
                              value: stats.lowStockCount.toString(),
                              color: stats.lowStockCount > 0 ? AppColors.warning : AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _PharmacyMiniStat(
                              label: l10n.expiringSoonLabel,
                              value: stats.expiringCount.toString(),
                              color: stats.expiringCount > 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _PharmacyMiniStat(
                              label: l10n.inventoryValueLabel,
                              value: '${stats.inventoryCostValue.toStringAsFixed(0)} DZD',
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
                        child: _AlertsCard(stats: stats),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _PharmacyQuickActions(),
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

class _PharmacyDashboardHeader extends StatelessWidget {
  const _PharmacyDashboardHeader({
    required this.company,
    required this.stats,
    required this.onOpenReports,
    required this.onOpenAiAssistant,
    required this.onOpenNotifications,
  });

  final CompanyInfo? company;
  final PharmacyDashboardStats stats;
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
                          company == null ? l10n.pharmacyDashboardTitle : '${company!.name} · ${company!.businessType}',
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

/// Same visual contract as ClinicMainDashboardScreen's/
/// RestaurantMainDashboardScreen's private `_KpiCard` — duplicated
/// (file-private in both) rather than exposing internals, keeping this
/// file's diff fully additive.
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

class _PharmacyMiniStat extends StatelessWidget {
  const _PharmacyMiniStat({required this.label, required this.value, required this.color});

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

/// Ch. 15's "Low-stock medicines/products" + "Expiring products" alerts,
/// surfaced directly on the main Dashboard — same "most important
/// right now" role as Clinic's patient queue card and Restaurant's
/// active-orders card.
class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.stats});

  final PharmacyDashboardStats stats;

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
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: l10n.productsTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductsListScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (stats.expiringProducts.isEmpty && stats.lowStockProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.noStockOrExpiryAlertsMessage,
                style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            )
          else ...[
            for (final p in stats.expiringProducts.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      color: p.isExpired ? AppColors.danger : AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.lineItemLabel(p.name, l10n.expiresOnLabel(_formatDate(p.expirationDate))),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            for (final p in stats.lowStockProducts.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p.name} · ${p.quantity} left (min ${p.minimumStock})',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Ch. 15/14 — fast access to a pharmacy's most important actions.
class _PharmacyQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.inventory_2_outlined, size: 20),
                label: Text(l10n.productsTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductsListScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                label: Text(l10n.creditPageTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreditScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
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

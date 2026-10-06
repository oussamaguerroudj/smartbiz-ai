import '../../../../core/widgets/directional_chevron.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../../auth/data/companies_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import '../../../../l10n/app_localizations.dart';
import 'restaurant_orders_screen.dart';
import 'restaurant_tables_screen.dart';
import 'restaurant_menu_screen.dart';
import 'restaurant_reservations_screen.dart';
import 'restaurant_order_detail_screen.dart';
import '../../../dashboard/presentation/widgets/dashboard_pages_section.dart';

/// Restaurant specialization of the MAIN Dashboard tab (business-
/// specialization brief Ch. 17; follows SPECIALIZED_MODULES.md §3/§6's
/// documented pattern, second vertical after Clinic).
///
/// Deliberately NOT a new design: reuses the exact same structural
/// chrome as [ClinicMainDashboardScreen] (itself matching the generic
/// [DashboardScreen]) — GradientHero header, the overlapping KPI-card
/// row, the same FadeSlideIn stagger, the same AnimatedCounter — only
/// the CONTENT changes:
///   - KPIs: orders today / active orders / today's revenue (never
///     product-sale figures)
///   - Body: active-orders snapshot (kitchen/table status) instead of
///     the sales trend chart, and restaurant quick actions instead of
///     "New Sale" / "Scan Invoice".

const double _kKpiCardHeight = 96;
const double _kKpiOverlap = 32;
const double _kKpiTopGap = AppSpacing.md;
const double _kKpiBottomGap = AppSpacing.md;

class RestaurantMainDashboardScreen extends ConsumerWidget {
  const RestaurantMainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(restaurantDashboardProvider);
    final companyAsync = ref.watch(companyInfoProvider);

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
                onPressed: () => ref.invalidate(restaurantDashboardProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(restaurantDashboardProvider);
            ref.invalidate(restaurantActiveOrdersProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _RestaurantDashboardHeader(
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
                    // Second KPI row — tables / reservations / outstanding
                    // payments, same money-card / stat-card visual
                    // language as Clinic's own second row.
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RestaurantMiniStat(
                              label: l10n.tablesOccupiedLabel,
                              value: '${stats.tablesOccupied}/${stats.tablesTotal}',
                              color: stats.tablesOccupied > 0 ? AppColors.warning : AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _RestaurantMiniStat(
                              label: l10n.reservationsTodayLabel,
                              value: stats.reservationsToday.toString(),
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _RestaurantMiniStat(
                              label: l10n.outstandingPaymentsLabel,
                              value: '${stats.outstandingPayments.toStringAsFixed(0)} DZD',
                              color: stats.outstandingPayments > 0 ? AppColors.warning : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 110),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _ActiveOrdersCard(
                          ordersAsync: ref.watch(restaurantActiveOrdersProvider),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _RestaurantQuickActions(),
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

class _RestaurantDashboardHeader extends StatelessWidget {
  const _RestaurantDashboardHeader({
    required this.company,
    required this.stats,
    required this.onOpenReports,
    required this.onOpenAiAssistant,
    required this.onOpenNotifications,
  });

  final CompanyInfo? company;
  final RestaurantDashboardStats stats;
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
                          company == null ? l10n.restaurantDashboardTitle : '${company!.name} · ${company!.businessType}',
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
                      label: l10n.todaysOrdersLabel,
                      value: stats.ordersToday.toDouble(),
                      decimals: 0,
                      color: AppColors.primary,
                      subtitle: l10n.dashboardToday,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.activeOrdersLabel,
                      value: stats.activeOrders.toDouble(),
                      decimals: 0,
                      color: stats.activeOrders > 0 ? AppColors.warning : AppColors.primary,
                      subtitle: l10n.inProgressLabel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.todayRevenueLabel,
                      value: stats.todayRevenue,
                      color: AppColors.info,
                      subtitle: l10n.kpiSubtitleDzdToday,
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

/// Same visual contract as ClinicMainDashboardScreen's private
/// `_KpiCard` — duplicated (file-private in that file too) rather than
/// exposing its internals, keeping this file's diff fully additive.
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

class _RestaurantMiniStat extends StatelessWidget {
  const _RestaurantMiniStat({required this.label, required this.value, required this.color});

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
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Ch. 17's "Kitchen/order status", surfaced directly on the main
/// Dashboard tab — same role as Clinic's `_PatientQueueCard`: the most
/// important "what's happening right now" snapshot, zero extra taps.
class _ActiveOrdersCard extends StatelessWidget {
  const _ActiveOrdersCard({required this.ordersAsync});

  final AsyncValue<List<RestaurantOrder>> ordersAsync;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.activeOrdersLabel, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const ForwardChevron(),
                tooltip: AppLocalizations.of(context)!.ordersTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RestaurantOrdersScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ordersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                AppLocalizations.of(context)!.networkError,
                style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            data: (orders) => _buildOrdersBody(context, orders),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersBody(BuildContext context, List<RestaurantOrder> orders) {
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          AppLocalizations.of(context)!.noActiveOrdersMessage,
          style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    final pending = orders.where((o) => o.status == RestaurantOrderStatus.pending).length;
    final preparing = orders.where((o) => o.status == RestaurantOrderStatus.preparing).length;
    final ready = orders.where((o) => o.status == RestaurantOrderStatus.ready).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final order in orders.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _OrderLine(order: order),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            if (pending > 0) Text(AppLocalizations.of(context)!.pendingCount(pending), style: AppTypography.caption(AppColors.warning)),
            if (preparing > 0) Text(AppLocalizations.of(context)!.preparingCount(preparing), style: AppTypography.caption(AppColors.info)),
            if (ready > 0) Text(AppLocalizations.of(context)!.readyCount(ready), style: AppTypography.caption(AppColors.primary)),
          ],
        ),
      ],
    );
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.order});

  final RestaurantOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = restaurantOrderStatusColor(order.status);
    final typeLabel = order.tableName ??
        (order.orderType == 'dine_in'
            ? l10n.dineInOption
            : order.orderType == 'delivery'
                ? l10n.deliveryOption
                : l10n.takeawayOption);

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantOrderDetailScreen(orderId: order.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.orderNumber.toString().padLeft(2, '0')} · $typeLabel${order.customerName != null && order.customerName!.isNotEmpty ? ' (${order.customerName})' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(restaurantOrderStatusLabel(order.status), style: AppTypography.caption(color)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            restaurantPaymentBadge(order, l10n),
          ],
        ),
      ),
    );
  }
}

/// Ch. 17/14 — fast access to a restaurant's most important actions, in
/// the same ElevatedButton/OutlinedButton visual language as the
/// generic dashboard's own quick actions (never a new button style).
class _RestaurantQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                label: Text(l10n.newOrderTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RestaurantOrdersScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.table_restaurant_outlined, size: 20),
                label: Text(l10n.tablesTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RestaurantTablesScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restaurant_menu_outlined, size: 20),
                label: Text(l10n.menuTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RestaurantMenuScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_seat_outlined, size: 20),
                label: Text(l10n.reservationsTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RestaurantReservationsScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

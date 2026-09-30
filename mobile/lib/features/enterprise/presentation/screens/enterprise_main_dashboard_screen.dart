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
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../employees/presentation/screens/employees_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../data/enterprise_repository.dart';
import '../../domain/enterprise_models.dart';
import 'enterprise_projects_screen.dart';

/// Enterprise / Company specialization of the MAIN Dashboard tab
/// (business-specialization brief Ch. 19; SPECIALIZED_MODULES.md §3's
/// documented pattern, sixth and last vertical).
///
/// Same approach as Pharmacy/Supérette/Clothing: `main_shell.dart` only
/// swaps THIS screen in for tab 0 — the CORE tabs and More menu stay,
/// and Clients/Employees/Invoices/Expenses/Reports ARE the CORE screens.
///
/// Deliberately NOT a new design: same GradientHero header, overlapping
/// KPI-card row, FadeSlideIn stagger and AnimatedCounter as every other
/// vertical's main dashboard — only the CONTENT changes: month
/// revenue/expenses/profit (a company's invoices are lumpy, so "today"
/// would often read as zero), unpaid invoices, and projects, with no
/// stock, product-sale or retail concepts anywhere on the screen.
final enterpriseDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.read(enterpriseRepositoryProvider).dashboard();
});

const double _kKpiCardHeight = 96;
const double _kKpiOverlap = 32;
const double _kKpiTopGap = AppSpacing.md;
const double _kKpiBottomGap = AppSpacing.md;

String _dzd(double v) => '${v.toStringAsFixed(0)} DZD';

class EnterpriseMainDashboardScreen extends ConsumerWidget {
  const EnterpriseMainDashboardScreen({super.key});

  Future<void> _openProjects(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EnterpriseProjectsScreen()),
    );
    // Projects may have been added/changed — refresh the summary.
    ref.invalidate(enterpriseDashboardProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(enterpriseDashboardProvider);
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
                onPressed: () => ref.invalidate(enterpriseDashboardProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(enterpriseDashboardProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _EnterpriseDashboardHeader(
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
                            child: _EnterpriseMiniStat(
                              label: l10n.openProjectsLabel,
                              value: stats.projects.open.toString(),
                              color: stats.projects.overdue > 0 ? AppColors.warning : AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _EnterpriseMiniStat(
                              label: l10n.moreCustomers,
                              value: stats.clientsCount.toString(),
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _EnterpriseMiniStat(
                              label: l10n.moreEmployees,
                              value: stats.employeesCount.toString(),
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
                        child: _FinanceCard(stats: stats),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _ProjectsCard(
                          stats: stats,
                          onOpenProjects: () => _openProjects(context, ref),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 170),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _UnpaidInvoicesCard(stats: stats),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _EnterpriseQuickActions(
                          onOpenProjects: () => _openProjects(context, ref),
                        ),
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

class _EnterpriseDashboardHeader extends StatelessWidget {
  const _EnterpriseDashboardHeader({
    required this.company,
    required this.stats,
    required this.onOpenReports,
    required this.onOpenAiAssistant,
    required this.onOpenNotifications,
  });

  final CompanyInfo? company;
  final EnterpriseDashboardStats stats;
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
                          l10n.goodDay,
                          style: AppTypography.body(Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          company == null ? l10n.companyDashboardTitle : '${company!.name} · ${company!.businessType}',
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
                      label: l10n.dashboardRevenue,
                      value: stats.monthRevenue,
                      color: AppColors.primary,
                      subtitle: l10n.dzdThisMonthLabel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.netProfitLabel,
                      value: stats.monthNetProfit,
                      color: stats.monthNetProfit < 0 ? AppColors.danger : AppColors.info,
                      subtitle: l10n.thisMonthLabel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.statusUnpaid,
                      value: stats.unpaidInvoicesAmount,
                      color: stats.unpaidInvoicesCount > 0 ? AppColors.warning : AppColors.success,
                      subtitle: l10n.lineItemLabel(l10n.invoiceFallback, stats.unpaidInvoicesCount),
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

/// Same visual contract as the other verticals' private `_KpiCard` —
/// duplicated (file-private in each) rather than exposing internals,
/// keeping this file's diff fully additive.
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

class _EnterpriseMiniStat extends StatelessWidget {
  const _EnterpriseMiniStat({required this.label, required this.value, required this.color});

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

/// Ch. 19's Revenue / Expenses / Profit (+ Salaries) — the "where does
/// the profit come from" card. Payroll is shown on its own line since
/// Ch. 19 lists Salaries separately, but it is already INCLUDED in the
/// expenses total (same as the CORE dashboard).
class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.stats});

  final EnterpriseDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    Widget row(String label, double value, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
              Text(
                _dzd(value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    ),
              ),
            ],
          ),
        );

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
          Text(l10n.thisMonthLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          row(l10n.dashboardRevenue, stats.monthRevenue),
          row(l10n.expensesTitle, stats.monthOperatingExpenses),
          row(l10n.salariesLabel, stats.monthPayroll),
          const Divider(height: AppSpacing.sm),
          row(
            l10n.netProfitLabel,
            stats.monthNetProfit,
            color: stats.monthNetProfit < 0 ? AppColors.danger : AppColors.primary,
            bold: true,
          ),
          Text(
            l10n.todayRevenueProfit(_dzd(stats.todayRevenue), _dzd(stats.todayNetProfit)),
            style: AppTypography.caption(muted),
          ),
        ],
      ),
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  const _ProjectsCard({required this.stats, required this.onOpenProjects});

  final EnterpriseDashboardStats stats;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
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
              Text(l10n.projectsTitle, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: l10n.projectsTitle,
                onPressed: onOpenProjects,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (stats.openProjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(l10n.noOpenProjectsMessage, style: AppTypography.body(muted)),
            )
          else ...[
            if (stats.projects.overdue > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  l10n.overdueCount(stats.projects.overdue),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
            for (final p in stats.openProjects.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      Icons.work_outline_rounded,
                      color: p.isOverdue ? AppColors.danger : AppColors.info,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.customerName == null ? p.name : '${p.name} · ${p.customerName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      p.dueDate ?? p.status.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: p.isOverdue ? AppColors.danger : null,
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

/// Ch. 19's "Outstanding invoices" — oldest first, so the owner sees who
/// to chase.
class _UnpaidInvoicesCard extends StatelessWidget {
  const _UnpaidInvoicesCard({required this.stats});

  final EnterpriseDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
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
              Text(l10n.unpaidInvoicesTitle, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: l10n.moreInvoices,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InvoicesScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (stats.unpaidInvoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(l10n.noUnpaidInvoicesMessage, style: AppTypography.body(muted)),
            )
          else
            for (final inv in stats.unpaidInvoices.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inv.customerName == null ? inv.invoiceNumber : '${inv.invoiceNumber} · ${inv.customerName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _dzd(inv.total),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          if (stats.clientBalancesOutstanding > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.clientCreditBalancesMessage(_dzd(stats.clientBalancesOutstanding)),
              style: AppTypography.caption(muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ch. 19 — fast access to a company's most important areas.
class _EnterpriseQuickActions extends StatelessWidget {
  const _EnterpriseQuickActions({required this.onOpenProjects});

  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                label: Text(l10n.moreInvoices),
                onPressed: () => open(const InvoicesScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.work_outline_rounded, size: 20),
                label: Text(l10n.projectsTitle),
                onPressed: onOpenProjects,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.people_alt_outlined, size: 20),
                label: Text(l10n.moreCustomers),
                onPressed: () => open(const CustomersScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.badge_outlined, size: 20),
                label: Text(l10n.moreEmployees),
                onPressed: () => open(const EmployeesScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

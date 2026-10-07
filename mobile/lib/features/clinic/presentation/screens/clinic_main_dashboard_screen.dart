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
import '../../../appointments/presentation/screens/appointments_screen.dart';
import '../../data/clinic_repository.dart';
import '../../domain/clinic_models.dart';
import 'clinic_dashboard_screen.dart' show clinicDashboardProvider;
import 'clinic_queue_screen.dart';
import 'clinic_patients_screen.dart';
import '../../../dashboard/presentation/widgets/dashboard_pages_section.dart';
import '../../../../l10n/app_localizations.dart';

/// Clinic specialization of the MAIN Dashboard tab (business-specialization
/// brief, Ch. 1-14; SPECIALIZED_MODULES.md §6/§7's flagged follow-up).
///
/// This is deliberately NOT a new design: it reuses the exact same
/// structural chrome as [DashboardScreen] (dashboard_screen.dart) —
/// GradientHero header, the overlapping KPI-card row, AppSpacing/
/// AppTypography/AppColors, the same FadeSlideIn stagger, the same
/// AnimatedCounter — only the CONTENT changes:
///   - KPIs: patients / waiting / today's revenue (never product sales)
///   - Body: patient queue snapshot (next patient, current consultation)
///     instead of the sales trend chart, and clinic quick actions
///     instead of "New Sale" / "Scan Invoice".
///
/// [MainShell] selects this screen for tab 0 instead of the generic
/// [DashboardScreen] only when `company.businessType == 'clinic'` — the
/// generic dashboard file itself is completely untouched, keeping this
/// change purely additive, per the brief's own "small blast radius" rule.
const double _kKpiCardHeight = 96;
const double _kKpiOverlap = 32;
const double _kKpiTopGap = AppSpacing.md;
const double _kKpiBottomGap = AppSpacing.md;

class ClinicMainDashboardScreen extends ConsumerWidget {
  const ClinicMainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(clinicDashboardProvider);
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
                onPressed: () => ref.invalidate(clinicDashboardProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clinicDashboardProvider);
            ref.invalidate(clinicQueueProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ClinicDashboardHeader(
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

                    // Second KPI row — clinic's own analytics beyond the
                    // top-of-header three, same money-card / stat-card
                    // visual language already used on ClinicDashboardScreen
                    // (Ch. 12), just surfaced here on the MAIN dashboard.
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ClinicMiniStat(
                              label: l10n.appointmentsTodayLabel,
                              value: stats.appointmentsToday.toString(),
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _ClinicMiniStat(
                              label: l10n.completedTodayLabel,
                              value: stats.completedToday.toString(),
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _ClinicMiniStat(
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
                        child: _PatientQueueCard(
                          queueAsync: ref.watch(clinicQueueProvider),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _ClinicQuickActions(),
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

class _ClinicDashboardHeader extends StatelessWidget {
  const _ClinicDashboardHeader({
    required this.company,
    required this.stats,
    required this.onOpenReports,
    required this.onOpenAiAssistant,
    required this.onOpenNotifications,
  });

  final CompanyInfo? company;
  final ClinicDashboardStats stats;
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
                          company == null ? l10n.clinicDashboardTitle : '${company!.name} · ${company!.businessType}',
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
                      label: l10n.patientsTodayLabel,
                      value: stats.patientsToday.toDouble(),
                      decimals: 0,
                      color: AppColors.primary,
                      subtitle: l10n.dashboardToday,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.waitingLabel,
                      value: stats.waitingCount.toDouble(),
                      decimals: 0,
                      color: stats.waitingCount > 0 ? AppColors.warning : AppColors.primary,
                      subtitle: l10n.dashboardToday,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _KpiCard(
                      label: l10n.todayRevenueLabel,
                      value: stats.todayRevenue,
                      color: AppColors.info,
                      subtitle: l10n.dashboardTodayCurrency('DZD'),
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

/// Same visual contract as dashboard_screen.dart's private `_KpiCard` —
/// duplicated (not imported, since the original is file-private) rather
/// than exposing dashboard_screen.dart's internals, keeping this file's
/// diff fully additive. Kept pixel-identical on purpose.
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

class _ClinicMiniStat extends StatelessWidget {
  const _ClinicMiniStat({required this.label, required this.value, required this.color});

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

/// Ch. 4 — "who is waiting / who is being seen / who is next", surfaced
/// directly on the main Dashboard tab instead of only inside the
/// dedicated Waiting Room screen, so this — the brief's own words —
/// "one of the most important features" is visible within a few seconds
/// of opening the app, with zero extra taps.
class _PatientQueueCard extends StatelessWidget {
  const _PatientQueueCard({required this.queueAsync});

  final AsyncValue<({List<ClinicQueueEntry> queue, String? nextPatient})> queueAsync;

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
              Text(l10n.clinicQueueTitle, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const ForwardChevron(),
                tooltip: l10n.clinicQueueTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClinicQueueScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          queueAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.networkError,
                style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            data: (result) => _buildQueueBody(context, l10n, result),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueBody(
    BuildContext context,
    AppLocalizations l10n,
    ({List<ClinicQueueEntry> queue, String? nextPatient}) result,
  ) {
    final entries = result.queue;
    final current = entries.where((e) => e.status == ClinicQueueStatus.inConsultation).toList();
    final waitingCount = entries.where((e) => e.status == ClinicQueueStatus.waiting).length;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          l10n.queueEmptyMessage,
          style: AppTypography.body(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.nextPatient != null)
          _QueueLine(
            title: l10n.nextPatientLabel(result.nextPatient!),
            color: AppColors.info,
            icon: Icons.arrow_forward_rounded,
          )
        else
          _QueueLine(
            title: l10n.noOneWaitingMessage,
            color: AppColors.primary,
            icon: Icons.check_circle_outline,
          ),
        for (final entry in current) ...[
          const SizedBox(height: AppSpacing.xs),
          _QueueLine(
            title: entry.patientName,
            subtitle: l10n.completeConsultationButton,
            color: AppColors.primary,
            icon: Icons.medical_services_outlined,
          ),
        ],
        if (waitingCount > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$waitingCount ${l10n.waitingLabel.toLowerCase()}',
            style: AppTypography.caption(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ],
    );
  }
}

class _QueueLine extends StatelessWidget {
  const _QueueLine({required this.title, required this.color, required this.icon, this.subtitle});

  final String title;
  final String? subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.caption(color),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ch. 14 — fast access to the clinic's most important actions, in the
/// same ElevatedButton/OutlinedButton visual language as the generic
/// dashboard's "New Sale" / "Scan Invoice" row (never a new button style).
class _ClinicQuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: Text(l10n.addPatientTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClinicPatientsScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 20),
                label: Text(l10n.newAppointmentTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
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
                icon: const Icon(Icons.campaign_outlined, size: 20),
                label: Text(l10n.callNextPatientButton),
                onPressed: () async {
                  try {
                    await ref.read(clinicRepositoryProvider).callNextPatient();
                    ref.invalidate(clinicQueueProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.networkError)),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 20),
                label: Text(l10n.clinicRecordPaymentAction),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClinicPatientsScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

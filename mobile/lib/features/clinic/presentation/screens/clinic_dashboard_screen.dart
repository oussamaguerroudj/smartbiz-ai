import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/clinic_repository.dart';
import 'clinic_queue_screen.dart';
import 'clinic_patients_screen.dart';
import '../../../../l10n/app_localizations.dart';

final clinicDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.read(clinicRepositoryProvider).dashboard();
});

/// Clinic Dashboard (Ch. 3.A) — adapts the app's Dashboard concept to a
/// clinic's own KPIs, without touching or removing the CORE Dashboard
/// (dashboard_screen.dart) at all; this is a fully separate screen only
/// ever reached when company.businessType == 'clinic' (see
/// main_shell.dart).
class ClinicDashboardScreen extends ConsumerWidget {
  const ClinicDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(clinicDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.clinicDashboardTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(clinicDashboardProvider),
        child: statsAsync.when(
          data: (stats) => ListView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(label: l10n.patientsTodayLabel, value: stats.patientsToday, color: AppColors.primary),
                  _StatCard(label: l10n.appointmentsTodayLabel, value: stats.appointmentsToday, color: AppColors.info),
                  _StatCard(label: l10n.waitingLabel, value: stats.waitingCount, color: AppColors.warning),
                  _StatCard(label: l10n.completedTodayLabel, value: stats.completedToday, color: AppColors.success),
                  _StatCard(label: l10n.noShowTodayLabel, value: stats.noShowToday, color: AppColors.danger),
                  _StatCard(label: l10n.newPatientsTodayLabel, value: stats.newPatientsToday, color: AppColors.primary),
                  _StatCard(label: l10n.doctorsLabel, value: stats.doctorCount, color: AppColors.info),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Ch. 9-11 — revenue is real patient consultation payments
              // (never product sales), profit = revenue - clinic
              // expenses. Same _MoneyCard visual language as the
              // count-based stats above — only the content differs.
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 1.6,
                children: [
                  _MoneyCard(label: l10n.todayRevenueLabel, value: stats.todayRevenue, color: AppColors.primary),
                  _MoneyCard(
                    label: l10n.todayProfitLabel,
                    value: stats.todayProfit,
                    color: stats.todayProfit >= 0 ? AppColors.success : AppColors.danger,
                  ),
                  _MoneyCard(
                    label: l10n.outstandingPaymentsLabel,
                    value: stats.outstandingPayments,
                    color: stats.outstandingPayments > 0 ? AppColors.warning : AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClinicQueueScreen()),
                ),
                icon: const Icon(Icons.groups_outlined),
                label: Text(l10n.clinicQueueTitle),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClinicPatientsScreen()),
                ),
                icon: const Icon(Icons.people_outline),
                label: Text(l10n.clinicPatientsTitle),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(l10n.networkError)),
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.label, required this.value, required this.color});
  final String label;
  final double value;
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${value.toStringAsFixed(0)} DZD',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label;
  final int value;
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

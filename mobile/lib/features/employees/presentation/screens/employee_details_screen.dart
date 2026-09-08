import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/employees_repository.dart';

class EmployeeDetailsScreen extends ConsumerWidget {
  const EmployeeDetailsScreen({super.key, required this.employeeId});
  final String employeeId;

  Future<void> _markAttendance(WidgetRef ref, String status) async {
    await ref.read(employeesRepositoryProvider.notifier).markAttendance(employeeId, status);
    ref.invalidate(employeeDetailsProvider(employeeId)); // refetch fresh counts
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(employeeDetailsProvider(employeeId));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(detailsAsync.valueOrNull?.employee.name ?? l10n.employeeFallback)),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (details) {
          final emp = details.employee;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.position, style: Theme.of(context).textTheme.titleMedium),
                      if (emp.phone != null) Text(emp.phone!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: _Stat(label: l10n.attendancePresent, value: '${details.attendance.present}')),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _Stat(
                      label: l10n.attendanceAbsent,
                      value: '${details.attendance.absent}',
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _Stat(
                      label: l10n.attendanceLate,
                      value: '${details.attendance.late}',
                      color: AppColors.warning,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.salaryThisMonth, style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${(details.salary?.net ?? emp.baseSalary).toStringAsFixed(0)} DZD',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      Text(l10n.baseSalaryValue(emp.baseSalary.toStringAsFixed(0))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _markAttendance(ref, 'present'),
                      child: Text(l10n.markPresent),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _markAttendance(ref, 'absent'),
                      child: Text(l10n.markAbsent),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

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
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

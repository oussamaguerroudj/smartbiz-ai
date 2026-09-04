import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(detailsAsync.valueOrNull?.employee.name ?? 'Employee')),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
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
                  Expanded(child: _Stat(label: 'Present', value: '${details.attendance.present}')),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _Stat(
                      label: 'Absent',
                      value: '${details.attendance.absent}',
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _Stat(
                      label: 'Late',
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
                          Text('Salary this month', style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${(details.salary?.net ?? emp.baseSalary).toStringAsFixed(0)} DZD',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      Text('Base: ${emp.baseSalary.toStringAsFixed(0)}'),
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
                      child: const Text('Mark Present'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _markAttendance(ref, 'absent'),
                      child: const Text('Mark Absent'),
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
        border: Border.all(color: Theme.of(context).dividerColor),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/employees_repository.dart';
import '../../domain/employee.dart';

class EmployeeDetailsScreen extends ConsumerWidget {
  const EmployeeDetailsScreen({super.key, required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesRepositoryProvider);
    final attendanceRepo = ref.watch(attendanceRepositoryProvider.notifier);
    final salaryRepo = ref.watch(salaryAdjustmentsRepositoryProvider.notifier);

    Employee? emp;
    for (final e in employees) {
      if (e.id == employeeId) {
        emp = e;
        break;
      }
    }
    if (emp == null) {
      return const Scaffold(body: Center(child: Text('Employee not found')));
    }

    final present =
        attendanceRepo.countByStatus(emp.id, AttendanceStatus.present);
    final absent =
        attendanceRepo.countByStatus(emp.id, AttendanceStatus.absent);
    final late = attendanceRepo.countByStatus(emp.id, AttendanceStatus.late);
    final netSalary = salaryRepo.netSalaryFor(emp.id, emp.baseSalary);

    return Scaffold(
      appBar: AppBar(title: Text(emp.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emp.position,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (emp.phone != null) Text(emp.phone!),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Present', value: '$present')),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: _Stat(
                      label: 'Absent',
                      value: '$absent',
                      color: AppColors.danger)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: _Stat(
                      label: 'Late', value: '$late', color: AppColors.warning)),
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
                      Text('Salary this month',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${netSalary.toStringAsFixed(0)} DZD',
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
                  onPressed: () => attendanceRepo.markAttendance(
                      emp!.id, AttendanceStatus.present),
                  child: const Text('Mark Present'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => attendanceRepo.markAttendance(
                      emp!.id, AttendanceStatus.absent),
                  child: const Text('Mark Absent'),
                ),
              ),
            ],
          ),
        ],
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
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color)),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

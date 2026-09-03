import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/employees_repository.dart';
import '../../domain/employee.dart';
import 'employee_details_screen.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesRepositoryProvider);
    final attendance = ref.watch(attendanceRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) {
          final emp = employees[i];
          final presentToday = attendance.any((r) =>
              r.employeeId == emp.id &&
              r.status == AttendanceStatus.present &&
              r.date.day == DateTime.now().day);
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => EmployeeDetailsScreen(employeeId: emp.id)),
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primary,
                    child: Text(emp.name.substring(0, 1)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(emp.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(emp.position),
                      ],
                    ),
                  ),
                  Text(
                    presentToday ? 'Present' : 'Absent',
                    style: TextStyle(
                      color:
                          presentToday ? AppColors.primary : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddEmployeeSheet(),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _AddEmployeeSheet extends ConsumerStatefulWidget {
  const _AddEmployeeSheet();
  @override
  ConsumerState<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends ConsumerState<_AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _salaryController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Employee', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Full name',
              controller: _nameController,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: 'Position', controller: _positionController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Base salary (DZD)',
              controller: _salaryController,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || double.tryParse(v) == null)
                  ? 'Enter a valid amount'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                ref.read(employeesRepositoryProvider.notifier).addEmployee(
                      name: _nameController.text,
                      position: _positionController.text.isEmpty
                          ? 'Staff'
                          : _positionController.text,
                      baseSalary: double.parse(_salaryController.text),
                    );
                Navigator.of(context).pop();
              },
              child: const Text('Save Employee'),
            ),
          ],
        ),
      ),
    );
  }
}

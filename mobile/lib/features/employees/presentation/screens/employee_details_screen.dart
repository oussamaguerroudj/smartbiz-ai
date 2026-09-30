import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../reports/data/reports_repository.dart';
import '../../data/employees_repository.dart';
import '../../domain/employee.dart';

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
      appBar: AppBar(
        title: Text(detailsAsync.valueOrNull?.employee.name ?? l10n.employeeFallback),
        actions: [
          if (detailsAsync.valueOrNull != null) ...[
            IconButton(
              tooltip: l10n.editAction,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final emp = detailsAsync.valueOrNull!.employee;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _EditEmployeeSheet(
                    employee: emp,
                    onUpdated: () => ref.invalidate(employeeDetailsProvider(employeeId)),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: l10n.deleteEmployeeTitle,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () async {
                final emp = detailsAsync.valueOrNull!.employee;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.deleteEmployeeTitle),
                    content: Text(l10n.deleteConfirmMessage(emp.name)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.delete),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  try {
                    await ref.read(employeesRepositoryProvider.notifier).deleteEmployee(employeeId);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${l10n.employeeFallback} "${emp.name}" ${l10n.delete.toLowerCase()}')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ],
      ),
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
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.payment_outlined),
                          label: Text(l10n.paySalary),
                          onPressed: () {
                            final defaultAmount = details.salary?.net ?? emp.baseSalary;
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => _RecordSalaryPaymentSheet(
                                employeeId: employeeId,
                                employeeName: emp.name,
                                initialAmount: defaultAmount,
                                onPaid: () {
                                  ref.invalidate(employeeDetailsProvider(employeeId));
                                  ref.invalidate(expensesRepositoryProvider);
                                  ref.invalidate(filteredReportProvider);
                                },
                              ),
                            );
                          },
                        ),
                      ),
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
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.salaryExpenseLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${details.salaryPayments.length}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (details.salaryPayments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history_outlined, size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 6),
                        Text(
                          l10n.noTransactionsYet,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...details.salaryPayments.map(
                  (payment) => Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                              payment.expenseDate,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${payment.amount.toStringAsFixed(0)} DZD',
                              style: AppTypography.bodyStrong(AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (payment.salaryPeriod != null) ...[
                              Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${l10n.salaryPeriodLabel}: ${payment.salaryPeriod}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (payment.duration != null) ...[
                              Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                payment.duration!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                        if (payment.description != null && payment.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            payment.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
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

class _EditEmployeeSheet extends ConsumerStatefulWidget {
  const _EditEmployeeSheet({required this.employee, required this.onUpdated});
  final Employee employee;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends ConsumerState<_EditEmployeeSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _positionController;
  late final TextEditingController _salaryController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _positionController = TextEditingController(text: widget.employee.position);
    _salaryController = TextEditingController(text: widget.employee.baseSalary.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (_nameController.text.trim().isEmpty || _positionController.text.trim().isEmpty) return;
    final salary = double.tryParse(_salaryController.text.trim()) ?? 0;
    setState(() => _isLoading = true);
    try {
      await ref.read(employeesRepositoryProvider.notifier).updateEmployee(
            widget.employee.id,
            name: _nameController.text.trim(),
            position: _positionController.text.trim(),
            baseSalary: salary,
          );
      widget.onUpdated();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editAction, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.nameLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.positionLabel, controller: _positionController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: l10n.baseSalaryLabel,
              controller: _salaryController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _update,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.editAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordSalaryPaymentSheet extends ConsumerStatefulWidget {
  const _RecordSalaryPaymentSheet({
    required this.employeeId,
    required this.employeeName,
    required this.initialAmount,
    required this.onPaid,
  });

  final String employeeId;
  final String employeeName;
  final double initialAmount;
  final VoidCallback onPaid;

  @override
  ConsumerState<_RecordSalaryPaymentSheet> createState() => _RecordSalaryPaymentSheetState();
}

class _RecordSalaryPaymentSheetState extends ConsumerState<_RecordSalaryPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _durationController;
  late final TextEditingController _noteController;

  DateTime _paymentDate = DateTime.now();
  late int _periodYear;
  late int _periodMonth;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodYear = now.year;
    _periodMonth = now.month;
    _amountController = TextEditingController(text: widget.initialAmount.toStringAsFixed(0));
    _durationController = TextEditingController(text: '1 month');
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _formattedPeriod =>
      '$_periodYear-${_periodMonth.toString().padLeft(2, '0')}';

  Future<void> _pickPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _pickSalaryPeriod() async {
    int tempYear = _periodYear;
    int tempMonth = _periodMonth;
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final monthNames = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setDialogState(() => tempYear--),
                  ),
                  Text('$tempYear', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setDialogState(() => tempYear++),
                  ),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(12, (index) {
                    final m = index + 1;
                    final isSelected = m == tempMonth;
                    return ChoiceChip(
                      label: Text(monthNames[index]),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => tempMonth = m);
                          Navigator.of(ctx).pop({'year': tempYear, 'month': tempMonth});
                        }
                      },
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _periodYear = result['year']!;
        _periodMonth = result['month']!;
      });
    }
  }

  Future<void> _submit({bool confirmedDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(employeesRepositoryProvider.notifier).paySalary(
            employeeId: widget.employeeId,
            amount: amount,
            paymentDate: _paymentDate,
            salaryPeriod: _formattedPeriod,
            duration: _durationController.text.trim().isEmpty ? '1 month' : _durationController.text.trim(),
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            confirmedDuplicate: confirmedDuplicate,
          );
      widget.onPaid();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.salaryPaidSuccess)),
        );
      }
    } on ApiException catch (e) {
      if ((e.statusCode == 409 || e.code == 'DUPLICATE_SALARY_PAYMENT') && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.duplicateSalaryWarningTitle),
            content: Text(l10n.duplicateSalaryWarningMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.confirmAction),
              ),
            ],
          ),
        );
        if (proceed == true && mounted) {
          await _submit(confirmedDuplicate: true);
          return;
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
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
              Text(
                '${l10n.recordSalaryPayment} — ${widget.employeeName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.amountDzdLabel,
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || double.tryParse(v) == null) ? l10n.enterValidAmount : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 18),
                      onPressed: _pickPaymentDate,
                      label: Text(
                        '${l10n.paymentDateLabel}: ${_paymentDate.year}-${_paymentDate.month.toString().padLeft(2, '0')}-${_paymentDate.day.toString().padLeft(2, '0')}',
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
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      onPressed: _pickSalaryPeriod,
                      label: Text(
                        '${l10n.salaryPeriodLabel}: $_formattedPeriod',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.durationLabel,
                controller: _durationController,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.descriptionLabel,
                hint: l10n.optionalNoteHint,
                controller: _noteController,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _submit(),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.confirmAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


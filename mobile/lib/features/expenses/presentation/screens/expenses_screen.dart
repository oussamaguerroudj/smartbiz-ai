import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reports/data/reports_repository.dart';
import '../../../employees/data/employees_repository.dart';
import '../../data/expenses_repository.dart';
import '../../domain/expense.dart';

IconData _categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('electric')) return Icons.lightbulb_outline;
  if (c.contains('transport') || c.contains('fuel')) return Icons.local_shipping_outlined;
  if (c.contains('rent')) return Icons.storefront_outlined;
  if (c.contains('water')) return Icons.water_drop_outlined;
  if (c.contains('salary') || c.contains('wage')) return Icons.badge_outlined;
  return Icons.receipt_long_outlined;
}

/// Expenses — Spec Ch. 20. Real API-backed with full CRUD.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteExpenseTitle),
        content: Text(
          l10n.deleteConfirmMessage('${expense.category} (${expense.amount.toStringAsFixed(0)} DZD)'),
        ),
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
    if (confirmed == true) {
      try {
        await ref.read(expensesRepositoryProvider.notifier).deleteExpense(expense.id);
        ref.invalidate(filteredReportProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  void _openEdit(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditExpenseSheet(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.expensesTitle)),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.read(expensesRepositoryProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            children: [
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.thisMonthTotal, style: AppTypography.body(Colors.white.withValues(alpha: 0.7))),
                      AnimatedCounter(
                        value: state.thisMonthTotal,
                        suffix: ' DZD',
                        style: AppTypography.statValue(Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (state.expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: AppSpacing.sm),
                        Text(l10n.noExpensesYet, style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              for (var i = 0; i < state.expenses.length; i++)
                FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      boxShadow: AppSpacing.cardElevation,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_categoryIcon(state.expenses[i].category), size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.expenses[i].category, style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${state.expenses[i].date.year}-${state.expenses[i].date.month.toString().padLeft(2, '0')}-${state.expenses[i].date.day.toString().padLeft(2, '0')}'
                                '${state.expenses[i].salaryPeriod != null ? " · ${l10n.salaryPeriodLabel}: ${state.expenses[i].salaryPeriod}" : ""}'
                                '${state.expenses[i].description != null && state.expenses[i].description!.isNotEmpty ? " · ${state.expenses[i].description}" : ""}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${state.expenses[i].amount.toStringAsFixed(0)} DZD',
                          style: AppTypography.bodyStrong(Theme.of(context).colorScheme.onSurface),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: l10n.editAction,
                          onPressed: () => _openEdit(context, state.expenses[i]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          tooltip: l10n.deleteExpenseTitle,
                          onPressed: () => _confirmDelete(context, ref, state.expenses[i]),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddExpenseSheet(),
        ),
      ),
    );
  }
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet();

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController(text: 'Electricity');
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  String? _selectedEmployeeId;
  int _salaryYear = DateTime.now().year;
  int _salaryMonth = DateTime.now().month;

  ExpensePeriodType _periodType = ExpensePeriodType.oneTime;
  DateTime _periodStart = DateTime.now();
  DateTime? _periodEnd;

  bool get _isSalary => _categoryController.text.trim().toLowerCase() == 'salary';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _periodStart : (_periodEnd ?? _periodStart);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _periodStart = picked;
        if (_periodEnd != null && _periodEnd!.isBefore(_periodStart)) {
          _periodEnd = _periodStart;
        }
      } else {
        _periodEnd = picked;
      }
    });
  }

  Future<void> _pickSalaryPeriod() async {
    int tempYear = _salaryYear;
    int tempMonth = _salaryMonth;
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
        _salaryYear = result['year']!;
        _salaryMonth = result['month']!;
      });
    }
  }

  String _periodPreview(AppLocalizations l10n) {
    DateTime end;
    switch (_periodType) {
      case ExpensePeriodType.oneTime:
      case ExpensePeriodType.daily:
        end = _periodStart;
        break;
      case ExpensePeriodType.monthly:
        end = DateTime(_periodStart.year, _periodStart.month + 1, 0);
        break;
      case ExpensePeriodType.yearly:
        end = DateTime(_periodStart.year + 1, _periodStart.month, _periodStart.day)
            .subtract(const Duration(days: 1));
        break;
      case ExpensePeriodType.custom:
        end = _periodEnd ?? _periodStart;
        break;
    }
    final days = end.difference(_periodStart).inDays + 1;
    final fmt = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${fmt(_periodStart)} → ${fmt(end)} (${l10n.expenseCoversDays(days)})';
  }

  Future<void> _save({bool confirmedDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final isSalary = _isSalary;
    if (isSalary && _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.chooseEmployee)),
      );
      return;
    }

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    final salaryPeriod = isSalary ? '$_salaryYear-${_salaryMonth.toString().padLeft(2, '0')}' : null;

    try {
      await ref.read(expensesRepositoryProvider.notifier).addExpense(
            category: _categoryController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            amount: double.parse(_amountController.text),
            periodType: _periodType,
            periodStart: _periodStart,
            periodEnd: _periodEnd,
            employeeId: isSalary ? _selectedEmployeeId : null,
            salaryPeriod: salaryPeriod,
            duration: isSalary ? '1 month' : null,
            confirmedDuplicate: confirmedDuplicate,
          );
      ref.invalidate(filteredReportProvider);
      if (mounted) Navigator.of(context).pop();
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
          await _save(confirmedDuplicate: true);
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
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSalary = _isSalary;
    final commonCategories = ['Electricity', 'Transport', 'Rent', 'Water', 'Salary', 'Supplies'];

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
              Text(l10n.addExpense, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              // Category quick chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: commonCategories.map((cat) {
                  final selected = _categoryController.text.trim().toLowerCase() == cat.toLowerCase();
                  return ChoiceChip(
                    label: Text(cat == 'Salary' ? l10n.salaryExpenseLabel : cat),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _categoryController.text = cat;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppTextField(
                label: l10n.categoryLabel,
                controller: _categoryController,
                onChanged: (_) => setState(() {}),
              ),
              if (isSalary) ...[
                const SizedBox(height: AppSpacing.sm),
                Consumer(
                  builder: (context, ref, _) {
                    final employeesAsync = ref.watch(employeesRepositoryProvider);
                    return employeesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(l10n.errorPrefix(e.toString())),
                      data: (employees) => DropdownButtonFormField<String>(
                        value: _selectedEmployeeId,
                        decoration: InputDecoration(
                          labelText: l10n.chooseEmployee,
                          border: const OutlineInputBorder(),
                        ),
                        items: employees
                            .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text('${e.name} (${e.position})'),
                                ))
                            .toList(),
                        onChanged: (id) {
                          setState(() {
                            _selectedEmployeeId = id;
                            if (id != null) {
                              final emp = employees.firstWhere((e) => e.id == id);
                              if (_amountController.text.isEmpty) {
                                _amountController.text = emp.baseSalary.toStringAsFixed(0);
                              }
                            }
                          });
                        },
                        validator: (v) => isSalary && v == null ? l10n.chooseEmployee : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  onPressed: _pickSalaryPeriod,
                  label: Text(
                    '${l10n.salaryPeriodLabel}: $_salaryYear-${_salaryMonth.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.descriptionLabel,
                hint: l10n.optionalNoteHint,
                controller: _descriptionController,
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
              DropdownButtonFormField<ExpensePeriodType>(
                value: _periodType,
                decoration: InputDecoration(labelText: l10n.expensePeriodTypeLabel),
                items: [
                  DropdownMenuItem(value: ExpensePeriodType.oneTime, child: Text(l10n.periodOneTime)),
                  DropdownMenuItem(value: ExpensePeriodType.daily, child: Text(l10n.periodDaily)),
                  DropdownMenuItem(value: ExpensePeriodType.monthly, child: Text(l10n.periodMonthly)),
                  DropdownMenuItem(value: ExpensePeriodType.yearly, child: Text(l10n.periodYearly)),
                  DropdownMenuItem(value: ExpensePeriodType.custom, child: Text(l10n.periodCustom)),
                ],
                onChanged: (v) => setState(() => _periodType = v!),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: true),
                      child: Text(
                        '${l10n.periodStartLabel}: '
                        '${_periodStart.year}-${_periodStart.month.toString().padLeft(2, '0')}-${_periodStart.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  if (_periodType == ExpensePeriodType.custom) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(isStart: false),
                        child: Text(
                          _periodEnd == null
                              ? l10n.periodEndLabel
                              : '${l10n.periodEndLabel}: '
                                  '${_periodEnd!.year}-${_periodEnd!.month.toString().padLeft(2, '0')}-${_periodEnd!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(_periodPreview(l10n), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _save(),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.saveExpense),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditExpenseSheet extends ConsumerStatefulWidget {
  const _EditExpenseSheet({required this.expense});
  final Expense expense;

  @override
  ConsumerState<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends ConsumerState<_EditExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  bool _isLoading = false;

  late ExpensePeriodType _periodType;
  late DateTime _periodStart;
  DateTime? _periodEnd;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: widget.expense.category);
    _descriptionController = TextEditingController(text: widget.expense.description ?? '');
    _amountController = TextEditingController(text: widget.expense.amount.toStringAsFixed(0));
    _periodType = widget.expense.periodType;
    _periodStart = widget.expense.periodStart;
    _periodEnd = widget.expense.periodEnd;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _periodStart : (_periodEnd ?? _periodStart);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _periodStart = picked;
        if (_periodEnd != null && _periodEnd!.isBefore(_periodStart)) {
          _periodEnd = _periodStart;
        }
      } else {
        _periodEnd = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(expensesRepositoryProvider.notifier).updateExpense(
            id: widget.expense.id,
            category: _categoryController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            amount: double.parse(_amountController.text),
            periodType: _periodType,
            periodStart: _periodStart,
            periodEnd: _periodEnd,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
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
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
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
            Text(l10n.editExpenseTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.categoryLabel, controller: _categoryController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: l10n.descriptionLabel,
              hint: l10n.optionalNoteHint,
              controller: _descriptionController,
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
            DropdownButtonFormField<ExpensePeriodType>(
              value: _periodType,
              decoration: InputDecoration(labelText: l10n.expensePeriodTypeLabel),
              items: [
                DropdownMenuItem(value: ExpensePeriodType.oneTime, child: Text(l10n.periodOneTime)),
                DropdownMenuItem(value: ExpensePeriodType.daily, child: Text(l10n.periodDaily)),
                DropdownMenuItem(value: ExpensePeriodType.monthly, child: Text(l10n.periodMonthly)),
                DropdownMenuItem(value: ExpensePeriodType.yearly, child: Text(l10n.periodYearly)),
                DropdownMenuItem(value: ExpensePeriodType.custom, child: Text(l10n.periodCustom)),
              ],
              onChanged: (v) => setState(() => _periodType = v!),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(
                      '${l10n.periodStartLabel}: '
                      '${_periodStart.year}-${_periodStart.month.toString().padLeft(2, '0')}-${_periodStart.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                if (_periodType == ExpensePeriodType.custom) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isStart: false),
                      child: Text(
                        _periodEnd == null
                            ? l10n.periodEndLabel
                            : '${l10n.periodEndLabel}: '
                                '${_periodEnd!.year}-${_periodEnd!.month.toString().padLeft(2, '0')}-${_periodEnd!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.updateExpenseAction),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

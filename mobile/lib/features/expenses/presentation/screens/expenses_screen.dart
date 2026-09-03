import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/expenses_repository.dart';

/// Expenses — Spec Ch. 20. List + Add in one file (small, cohesive feature).
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesRepositoryProvider);
    final repo = ref.read(expensesRepositoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          ...expenses.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.category,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${e.date.month}/${e.date.day}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text('${e.amount.toStringAsFixed(0)} DZD'),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("This month's total",
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${repo.thisMonthTotal.toStringAsFixed(0)} DZD',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.danger),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddExpenseSheet(),
        ),
        child: const Icon(Icons.add, color: Colors.white),
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
            Text('Add Expense', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: 'Category', controller: _categoryController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Description',
              hint: 'Optional note',
              controller: _descriptionController,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Amount (DZD)',
              controller: _amountController,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || double.tryParse(v) == null)
                  ? 'Enter a valid amount'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                ref.read(expensesRepositoryProvider.notifier).addExpense(
                      category: _categoryController.text,
                      amount: double.parse(_amountController.text),
                      date: DateTime.now(),
                      description: _descriptionController.text,
                    );
                Navigator.of(context).pop();
              },
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

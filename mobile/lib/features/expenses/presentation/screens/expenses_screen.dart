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
import '../../data/expenses_repository.dart';

IconData _categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('electric')) return Icons.lightbulb_outline;
  if (c.contains('transport') || c.contains('fuel')) return Icons.local_shipping_outlined;
  if (c.contains('rent')) return Icons.storefront_outlined;
  if (c.contains('water')) return Icons.water_drop_outlined;
  if (c.contains('salary') || c.contains('wage')) return Icons.badge_outlined;
  return Icons.receipt_long_outlined;
}

/// Expenses — Spec Ch. 20. Real API-backed (Phase 5 wiring).
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(child: Text(l10n.noExpensesYet)),
                ),
              for (var i = 0; i < state.expenses.length; i++)
                FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      boxShadow: AppSpacing.cardElevation,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_categoryIcon(state.expenses[i].category), size: 17, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(state.expenses[i].category, style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${state.expenses[i].date.month}/${state.expenses[i].date.day}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Text('${state.expenses[i].amount.toStringAsFixed(0)} DZD',
                            style: AppTypography.bodyStrong(Theme.of(context).colorScheme.onSurface)),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(expensesRepositoryProvider.notifier).addExpense(
            category: _categoryController.text,
            amount: double.parse(_amountController.text),
            description: _descriptionController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
            Text(l10n.addExpense, style: Theme.of(context).textTheme.titleLarge),
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
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
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
    );
  }
}

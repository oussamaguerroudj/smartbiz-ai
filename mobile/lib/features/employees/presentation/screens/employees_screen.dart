import '../../../../core/widgets/directional_chevron.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/employees_repository.dart';
import 'employee_details_screen.dart';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employeesTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchInventoryHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(employeesRepositoryProvider.notifier).load();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.sm),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                ref.read(employeesRepositoryProvider.notifier).load(query: val);
                setState(() {});
              },
            ),
          ),
        ),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (employees) => employees.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: 64, color: Theme.of(context).disabledColor),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.noEmployeesFound, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(employeesRepositoryProvider.notifier).load(
                      query: _searchController.text,
                    ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: employees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final emp = employees[i];
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 40 * i),
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EmployeeDetailsScreen(employeeId: emp.id)),
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                            boxShadow: AppSpacing.cardElevation,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [AppColors.primaryLight.withValues(alpha: 0.35), AppColors.primary],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _initials(emp.name),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(emp.name, style: Theme.of(context).textTheme.titleMedium),
                                    Text(emp.position),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${emp.baseSalary.toStringAsFixed(0)} DZD',
                                    style: AppTypography.bodyStrong(AppColors.primaryDark),
                                  ),
                                  const SizedBox(height: 2),
                                  ForwardChevron(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddEmployeeSheet(),
        ),
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
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await ref.read(employeesRepositoryProvider.notifier).addEmployee(
            name: _nameController.text.trim(),
            position: _positionController.text.trim().isEmpty ? l10n.staffDefault : _positionController.text.trim(),
            baseSalary: double.parse(_salaryController.text.trim()),
          );
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.addEmployee, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.fullName,
                controller: _nameController,
                validator: (v) => (v == null || v.isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: l10n.positionLabel, controller: _positionController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.baseSalaryLabel,
                controller: _salaryController,
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? l10n.enterValidAmount : null,
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
                    : Text(l10n.saveEmployee),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/enterprise_repository.dart';
import '../../domain/enterprise_models.dart';

final enterpriseProjectsProvider = FutureProvider.autoDispose((ref) {
  return ref.read(enterpriseRepositoryProvider).listProjects();
});

Color _statusColor(EnterpriseProjectStatus status) => switch (status) {
      EnterpriseProjectStatus.planned => AppColors.info,
      EnterpriseProjectStatus.active => AppColors.primary,
      EnterpriseProjectStatus.onHold => AppColors.warning,
      EnterpriseProjectStatus.completed => AppColors.success,
      EnterpriseProjectStatus.cancelled => AppColors.danger,
    };

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Projects (Ch. 19 — "Projects"). The one Enterprise-only list: open
/// projects first (most urgent due date on top), then finished ones,
/// with a quick status change per project.
class EnterpriseProjectsScreen extends ConsumerWidget {
  const EnterpriseProjectsScreen({super.key});

  Future<void> _setStatus(
    WidgetRef ref,
    BuildContext context,
    EnterpriseProject project,
    EnterpriseProjectStatus status,
  ) async {
    try {
      await ref.read(enterpriseRepositoryProvider).updateProjectStatus(project.id, status);
      ref.invalidate(enterpriseProjectsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(enterpriseProjectsProvider);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.projectsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddProjectSheet(),
          );
          ref.invalidate(enterpriseProjectsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.noProjectsYetMessage, style: AppTypography.body(muted)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(enterpriseProjectsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final p = projects[i];
                final color = p.isOverdue ? AppColors.danger : _statusColor(p.status);
                final details = [
                  if (p.customerName != null) p.customerName!,
                  if (p.dueDate != null) 'Due ${p.dueDate}',
                  if (p.budget != null) '${p.budget!.toStringAsFixed(0)} DZD',
                ].join(' · ');
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                            if (details.isNotEmpty) Text(details, style: Theme.of(context).textTheme.bodySmall),
                            Text(
                              p.isOverdue ? '${p.status.localizedLabel(AppLocalizations.of(context)!)} · ${AppLocalizations.of(context)!.projectStatusOverdue}' : p.status.localizedLabel(AppLocalizations.of(context)!),
                              style: TextStyle(color: color, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<EnterpriseProjectStatus>(
                        tooltip: AppLocalizations.of(context)!.changeStatusTitle,
                        onSelected: (status) => _setStatus(ref, context, p, status),
                        itemBuilder: (context) => [
                          for (final s in EnterpriseProjectStatus.values)
                            if (s != p.status) PopupMenuItem(value: s, child: Text(s.localizedLabel(AppLocalizations.of(context)!))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(AppLocalizations.of(context)!.networkError)),
      ),
    );
  }
}

class _AddProjectSheet extends ConsumerStatefulWidget {
  const _AddProjectSheet();

  @override
  ConsumerState<_AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends ConsumerState<_AddProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _customerId;
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate != null && _dueDate != null && _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.dueDateBeforeStartDateError)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final budgetText = _budgetController.text.trim();
      await ref.read(enterpriseRepositoryProvider).createProject(
            name: _nameController.text.trim(),
            customerId: _customerId,
            description: _descriptionController.text.trim(),
            budget: budgetText.isEmpty ? null : double.tryParse(budgetText),
            startDate: _startDate == null ? null : _dateStr(_startDate!),
            dueDate: _dueDate == null ? null : _dateStr(_dueDate!),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(customersRepositoryProvider).valueOrNull ?? const <Customer>[];

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.newProjectTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: AppLocalizations.of(context)!.projectNameLabel,
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (clients.isNotEmpty) ...[
                Text(AppLocalizations.of(context)!.clientOptionalLabel, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: _customerId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(AppLocalizations.of(context)!.noClientOption)),
                    for (final c in clients) DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppTextField(
                label: AppLocalizations.of(context)!.budgetDzdOptionalLabel,
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim());
                  return (n == null || n < 0) ? AppLocalizations.of(context)!.enterValidAmount : null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: AppLocalizations.of(context)!.descriptionOptionalLabel, controller: _descriptionController),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.of(context)!.startDateLabel),
                subtitle: Text(_startDate == null ? 'Not set' : _dateStr(_startDate!)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final d = await _pickDate(_startDate);
                  if (d != null) setState(() => _startDate = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.of(context)!.dueDateLabel),
                subtitle: Text(_dueDate == null ? 'Not set' : _dateStr(_dueDate!)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final d = await _pickDate(_dueDate ?? _startDate);
                  if (d != null) setState(() => _dueDate = d);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(AppLocalizations.of(context)!.saveAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/appointments_repository.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  (PillTone, bool) _statusStyle(String s) => switch (s) {
        'scheduled' => (PillTone.brand, true),
        'completed' => (PillTone.neutral, false),
        'cancelled' => (PillTone.danger, false),
        _ => (PillTone.danger, false), // no_show
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsRepositoryProvider);
    final repo = ref.read(appointmentsRepositoryProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appointmentsTitle)),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (appointments) => appointments.isEmpty
            ? Center(child: Text(l10n.noAppointmentsScheduled))
            : RefreshIndicator(
                onRefresh: () => repo.load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: appointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final a = appointments[i];
                    final (tone, pulse) = _statusStyle(a.status);
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 40 * i),
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
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.schedule_rounded, size: 17, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.appointmentTimeName(
                                    '${a.scheduledAt.hour.toString().padLeft(2, '0')}:${a.scheduledAt.minute.toString().padLeft(2, '0')}',
                                    a.displayName,
                                  ),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (a.notes != null) Text(a.notes!),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (s) => repo.updateStatus(a.id, s),
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'completed', child: Text(l10n.markCompleted)),
                              PopupMenuItem(value: 'cancelled', child: Text(l10n.cancelAppointment)),
                            ],
                            child: StatusPill(label: a.status, tone: tone, pulse: pulse),
                          ),
                        ],
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
          builder: (_) => const _AddAppointmentSheet(),
        ),
      ),
    );
  }
}

class _AddAppointmentSheet extends ConsumerStatefulWidget {
  const _AddAppointmentSheet();
  @override
  ConsumerState<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends ConsumerState<_AddAppointmentSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();
  bool _isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      await ref.read(appointmentsRepositoryProvider.notifier).addAppointment(
            customerName: _nameController.text,
            scheduledAt: DateTime(now.year, now.month, now.day, _time.hour, _time.minute),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.newAppointmentTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.patientCustomerLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
              child: Text(l10n.timeLabel(_time.format(context))),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.notesLabel, hint: l10n.optionalHint, controller: _notesController),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.saveAppointment),
            ),
          ],
        ),
      ),
    );
  }
}

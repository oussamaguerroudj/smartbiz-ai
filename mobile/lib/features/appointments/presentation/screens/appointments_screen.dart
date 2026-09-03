import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/appointments_repository.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  Color _statusColor(AppointmentStatus s) => switch (s) {
        AppointmentStatus.scheduled => AppColors.info,
        AppointmentStatus.completed => AppColors.primary,
        AppointmentStatus.cancelled => AppColors.danger,
        AppointmentStatus.noShow => AppColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsRepositoryProvider);
    final repo = ref.read(appointmentsRepositoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: appointments.isEmpty
          ? const Center(child: Text('No appointments scheduled'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: appointments.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final a = appointments[i];
                return Container(
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
                            Text(
                              '${a.scheduledAt.hour.toString().padLeft(2, '0')}:${a.scheduledAt.minute.toString().padLeft(2, '0')} — ${a.customerName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (a.notes != null) Text(a.notes!),
                          ],
                        ),
                      ),
                      PopupMenuButton<AppointmentStatus>(
                        onSelected: (s) => repo.updateStatus(a.id, s),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                              value: AppointmentStatus.completed,
                              child: Text('Mark Completed')),
                          PopupMenuItem(
                              value: AppointmentStatus.cancelled,
                              child: Text('Cancel')),
                        ],
                        child: Chip(
                          label: Text(a.status.name),
                          backgroundColor:
                              _statusColor(a.status).withValues(alpha: 0.12),
                          labelStyle: TextStyle(color: _statusColor(a.status)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddAppointmentSheet(),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _AddAppointmentSheet extends ConsumerStatefulWidget {
  const _AddAppointmentSheet();
  @override
  ConsumerState<_AddAppointmentSheet> createState() =>
      _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends ConsumerState<_AddAppointmentSheet> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text('New Appointment',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
              label: 'Patient / Customer', controller: _nameController),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () async {
              final picked =
                  await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
            child: Text('Time: ${_time.format(context)}'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
              label: 'Notes', hint: 'Optional', controller: _notesController),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isEmpty) return;
              final now = DateTime.now();
              ref.read(appointmentsRepositoryProvider.notifier).addAppointment(
                    customerName: _nameController.text,
                    scheduledAt: DateTime(
                        now.year, now.month, now.day, _time.hour, _time.minute),
                    notes: _notesController.text.isEmpty
                        ? null
                        : _notesController.text,
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Save Appointment'),
          ),
        ],
      ),
    );
  }
}

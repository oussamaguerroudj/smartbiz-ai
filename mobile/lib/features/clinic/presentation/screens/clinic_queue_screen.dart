import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/clinic_repository.dart';
import '../../domain/clinic_models.dart';
import 'clinic_patients_screen.dart' show clinicPatientsProvider;
import '../../../../l10n/app_localizations.dart';

final clinicQueueProvider = FutureProvider.autoDispose((ref) {
  return ref.read(clinicRepositoryProvider).queue();
});

/// Waiting Room / Queue Management (Ch. 3.F)  -  explicitly called out as
/// one of the most important clinic features. Shows the live queue in
/// order (#01, #02, ...), the "Next Patient: X" banner, and the single
/// "Call Next Patient" action that moves the earliest WAITING entry to
/// IN_CONSULTATION.
class ClinicQueueScreen extends ConsumerStatefulWidget {
  const ClinicQueueScreen({super.key});

  @override
  ConsumerState<ClinicQueueScreen> createState() => _ClinicQueueScreenState();
}

class _CompletionResult {
  const _CompletionResult({required this.price, required this.amountPaid});
  final double price;
  final double amountPaid;
}

class _ClinicQueueScreenState extends ConsumerState<ClinicQueueScreen> {
  bool _isCallingNext = false;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callNext() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isCallingNext = true);
    try {
      await ref.read(clinicRepositoryProvider).callNextPatient();
      ref.invalidate(clinicQueueProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(l10n.networkError);
    } finally {
      if (mounted) setState(() => _isCallingNext = false);
    }
  }

  Future<void> _complete(ClinicQueueEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _showCompletionDialog(entry);
    if (result == null) return;

    try {
      await ref.read(clinicRepositoryProvider).completeConsultation(
            entry.id,
            consultationPrice: result.price,
            amountPaid: result.amountPaid,
          );
      ref.invalidate(clinicQueueProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(l10n.networkError);
    }
  }

  /// Ch. 7  -  captures the consultation price and (if paid on the spot)
  /// the amount paid right when the consultation is marked complete,
  /// since that's the one moment the doctor/receptionist is already
  /// looking at this patient and knows both numbers.
  Future<_CompletionResult?> _showCompletionDialog(ClinicQueueEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final priceController = TextEditingController();
    final paidController = TextEditingController();
    bool markFullyPaid = true;

    return showDialog<_CompletionResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.completeConsultationButton),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.consultationPriceLabel),
                  onChanged: (value) {
                    if (markFullyPaid) {
                      paidController.text = value;
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: markFullyPaid,
                  title: Text(l10n.markFullyPaidLabel),
                  onChanged: (checked) => setDialogState(() {
                    markFullyPaid = checked ?? false;
                    if (markFullyPaid) paidController.text = priceController.text;
                  }),
                ),
                if (!markFullyPaid)
                  TextField(
                    controller: paidController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.amountPaidLabel),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceController.text) ?? 0;
                final paid = double.tryParse(paidController.text) ?? 0;
                Navigator.of(dialogContext).pop(_CompletionResult(price: price, amountPaid: paid));
              },
              child: Text(l10n.completeConsultationButton),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(ClinicQueueEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(clinicRepositoryProvider).cancelQueueEntry(entry.id);
      ref.invalidate(clinicQueueProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(l10n.networkError);
    }
  }

  /// Ch. 3.F  -  "Allow adding a patient directly to the queue from the
  /// Waiting Room page. The user should be able to select an existing
  /// patient." Opens a search-and-pick sheet; the actual duplicate-entry
  /// guard lives server-side (clinic.repository.addToQueue), so whatever
  /// message the backend returns (e.g. "This patient is already in the
  /// waiting queue") is shown as-is rather than re-implemented here.
  Future<void> _openAddPatientSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<ClinicPatient>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PatientPickerSheet(),
    );
    if (selected == null || !mounted) return;

    try {
      await ref.read(clinicRepositoryProvider).addToQueue(patientId: selected.id);
      ref.invalidate(clinicQueueProvider);
      if (mounted) _showSnack(l10n.patientAddedMessage);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(l10n.networkError);
    }
  }

  Color _statusColor(ClinicQueueStatus status) => switch (status) {
        ClinicQueueStatus.waiting => AppColors.warning,
        ClinicQueueStatus.next => AppColors.info,
        ClinicQueueStatus.inConsultation => AppColors.primary,
        ClinicQueueStatus.completed => AppColors.success,
        ClinicQueueStatus.cancelled => AppColors.danger,
      };

  String _statusLabel(ClinicQueueStatus status) => switch (status) {
        ClinicQueueStatus.waiting => 'Waiting',
        ClinicQueueStatus.next => 'Next',
        ClinicQueueStatus.inConsultation => 'In Consultation',
        ClinicQueueStatus.completed => 'Completed',
        ClinicQueueStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final queueAsync = ref.watch(clinicQueueProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.clinicQueueTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddPatientSheet,
        tooltip: l10n.addToQueueAction,
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: queueAsync.when(
        data: (result) {
          final entries = result.queue;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(clinicQueueProvider),
            child: Column(
              children: [
                if (result.nextPatient != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    ),
                    child: Text(
                      l10n.nextPatientLabel(result.nextPatient!),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary),
                    ),
                  ),
                Expanded(
                  child: entries.isEmpty
                      ? Center(child: Text(l10n.queueEmptyMessage))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, i) {
                            final entry = entries[i];
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                                boxShadow: AppSpacing.cardElevation,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _statusColor(entry.status).withValues(alpha: 0.15),
                                    foregroundColor: _statusColor(entry.status),
                                    child: Text('#${entry.position.toString().padLeft(2, '0')}'),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.patientName, style: Theme.of(context).textTheme.titleMedium),
                                        Text(
                                          _statusLabel(entry.status),
                                          style: TextStyle(color: _statusColor(entry.status), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (entry.status == ClinicQueueStatus.inConsultation)
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                                      onPressed: () => _complete(entry),
                                    ),
                                  if (entry.status == ClinicQueueStatus.waiting)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.danger),
                                      onPressed: () => _cancel(entry),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ElevatedButton.icon(
                    onPressed: _isCallingNext ? null : _callNext,
                    icon: _isCallingNext
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.campaign_outlined),
                    label: Text(l10n.callNextPatientButton),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.networkError)),
      ),
    );
  }
}

/// Search-and-select sheet reusing the same patients list the Patients
/// tab already loads (clinicPatientsProvider)  -  no second "list all
/// patients" code path to keep in sync.
class _PatientPickerSheet extends ConsumerStatefulWidget {
  const _PatientPickerSheet();

  @override
  ConsumerState<_PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends ConsumerState<_PatientPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final patientsAsync = ref.watch(clinicPatientsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.selectPatientTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchPatientsHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: patientsAsync.when(
                data: (patients) {
                  final filtered = _query.isEmpty
                      ? patients
                      : patients
                          .where((p) => p.fullName.toLowerCase().contains(_query.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(child: Text(l10n.noPatientsFoundMessage));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final patient = filtered[i];
                      return ListTile(
                        title: Text(patient.fullName),
                        subtitle: patient.phone != null ? Text(patient.phone!) : null,
                        onTap: () => Navigator.of(context).pop(patient),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.networkError)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

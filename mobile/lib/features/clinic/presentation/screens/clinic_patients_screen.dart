import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/clinic_repository.dart';
import '../../domain/clinic_models.dart';
import 'clinic_patient_profile_screen.dart';
import '../../../../l10n/app_localizations.dart';

final clinicPatientsProvider = FutureProvider.autoDispose((ref) {
  return ref.read(clinicRepositoryProvider).listPatients();
});

/// Patients list (Ch. 3.B)  -  tapping a patient opens their full
/// Patient Profile (Ch. 3.C); the FAB opens the Add Patient form.
class ClinicPatientsScreen extends ConsumerStatefulWidget {
  const ClinicPatientsScreen({super.key});

  @override
  ConsumerState<ClinicPatientsScreen> createState() => _ClinicPatientsScreenState();
}

class _ClinicPatientsScreenState extends ConsumerState<ClinicPatientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final patientsAsync = ref.watch(clinicPatientsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.clinicPatientsTitle)),
      floatingActionButton: FloatingActionButton(
        // heroTag: null -> no Hero for this FAB. MainShell keeps every tab alive
        // in an IndexedStack, so two tab Scaffolds (each with a FAB) sit in ONE
        // route subtree; with Flutter's default shared FAB tag that throws
        // "There are multiple heroes that share the same tag within a subtree"
        // on every push/pop (seen repeatedly in flutter_runtime.log).
        heroTag: null,
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddPatientSheet(),
          );
          ref.invalidate(clinicPatientsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchProductsHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: patientsAsync.when(
              data: (patients) {
                final filtered = _query.isEmpty
                    ? patients
                    : patients
                        .where((p) => p.fullName.toLowerCase().contains(_query.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.noProductsLoadedYet));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final patient = filtered[i];
                    return ListTile(
                      title: Text(patient.fullName),
                      subtitle: patient.phone != null ? Text(patient.phone!) : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ClinicPatientProfileScreen(patientId: patient.id)),
                      ),
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
    );
  }
}

class _AddPatientSheet extends ConsumerStatefulWidget {
  const _AddPatientSheet();

  @override
  ConsumerState<_AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends ConsumerState<_AddPatientSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(clinicRepositoryProvider).createPatient(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.patientAddedMessage)));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.addPatientTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.fullNameLabel,
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fullNameLabel : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: l10n.phoneLabel, controller: _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.savePatient),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

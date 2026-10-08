import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/clinic_repository.dart';
import '../../domain/clinic_models.dart';
import 'clinic_prescription_form_screen.dart';
import 'clinic_invoice_view_screen.dart';
import '../../../../l10n/app_localizations.dart';

final clinicPatientProfileProvider =
    FutureProvider.autoDispose.family((ref, String patientId) {
  return ref.read(clinicRepositoryProvider).patientProfile(patientId);
});

/// Patient Profile (Ch. 3.C)  -  personal info at top, full Visit
/// History (Ch. 3.H) below, plus a quick action to add this patient to
/// today's Queue (Ch. 3.F) without needing to go back to the Queue
/// screen and search for them again.
class ClinicPatientProfileScreen extends ConsumerWidget {
  const ClinicPatientProfileScreen({super.key, required this.patientId});
  final String patientId;

  Future<void> _addToQueue(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(clinicRepositoryProvider).addToQueue(patientId: patientId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.addToQueueAction)));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    }
  }

  Color _paymentStatusColor(ClinicPaymentStatus status) => switch (status) {
        ClinicPaymentStatus.paid => AppColors.success,
        ClinicPaymentStatus.partiallyPaid => AppColors.warning,
        ClinicPaymentStatus.refunded => AppColors.info,
        ClinicPaymentStatus.unpaid => AppColors.danger,
      };

  String _paymentStatusLabel(AppLocalizations l10n, ClinicPaymentStatus status) => switch (status) {
        ClinicPaymentStatus.paid => l10n.paymentStatusPaidLabel,
        ClinicPaymentStatus.partiallyPaid => l10n.paymentStatusPartialLabel,
        ClinicPaymentStatus.refunded => l10n.paymentStatusRefundedLabel,
        ClinicPaymentStatus.unpaid => l10n.paymentStatusUnpaidLabel,
      };

  Future<void> _recordPayment(BuildContext context, WidgetRef ref, ClinicVisit visit) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: visit.remaining.toStringAsFixed(0));

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clinicRecordPaymentAction),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.amountPaidLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(double.tryParse(controller.text)),
            child: Text(l10n.clinicRecordPaymentAction),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !context.mounted) return;

    try {
      await ref.read(clinicRepositoryProvider).recordPayment(visit.id, amount: amount);
      ref.invalidate(clinicPatientProfileProvider(patientId));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    }
  }

  /// Ch. 4 (remaining-issues pass)  -  real file picker + real upload.
  /// Picks a PDF or image, reads its bytes, and uploads via
  /// ClinicRepository.addDocument (base64-in-JSON to the backend,
  /// which now does real local-disk storage  -  see clinic_repository's
  /// doc comment for why base64 and not multipart).
  Future<void> _addDocument(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    const mimeByExtension = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    final mimeType = mimeByExtension[(file.extension ?? '').toLowerCase()];
    if (mimeType == null) return;

    final nameController = TextEditingController(text: file.name);
    final typeController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addDocumentAction),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: l10n.documentNameLabel,
                  controller: nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: l10n.documentTypeLabel, controller: typeController),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: l10n.descriptionLabel, controller: descController),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: Text(l10n.addDocumentAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(clinicRepositoryProvider).addDocument(
            patientId: patientId,
            fileName: nameController.text.trim(),
            bytes: bytes,
            mimeType: mimeType,
            documentType: typeController.text.trim().isEmpty ? null : typeController.text.trim(),
            description: descController.text.trim().isEmpty ? null : descController.text.trim(),
          );
      ref.invalidate(clinicPatientProfileProvider(patientId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.documentAddedMessage)));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    }
  }

  /// Ch. 4 "preview when supported"  -  PDFs and images both go through
  /// `printing`'s preview sheet (it renders images too, not just PDF,
  /// so this covers every ALLOWED_DOCUMENT_TYPES value without a
  /// separate image-viewer dependency).
  Future<void> _previewDocument(BuildContext context, WidgetRef ref, ClinicDocument doc) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final bytes = await ref.read(clinicRepositoryProvider).fetchDocumentBytes(doc.id);
      if (!context.mounted) return;
      if (doc.fileType == 'application/pdf') {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: doc.fileName);
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) => Dialog(child: Image.memory(bytes)),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    }
  }

  Future<void> _deleteDocument(BuildContext context, WidgetRef ref, ClinicDocument doc) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteDocumentMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(clinicRepositoryProvider).deleteDocument(doc.id);
      ref.invalidate(clinicPatientProfileProvider(patientId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.documentDeletedMessage)));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    }
  }

  Future<void> _openNewPrescription(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClinicPrescriptionFormScreen(patientId: patientId)),
    );
    if (saved == true) {
      ref.invalidate(clinicPatientProfileProvider(patientId));
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(clinicPatientProfileProvider(patientId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.patientProfileTitle)),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                boxShadow: AppSpacing.cardElevation,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.patient.fullName, style: Theme.of(context).textTheme.titleLarge),
                  if (profile.patient.phone != null) Text(profile.patient.phone!),
                  if (profile.patient.gender != null) Text(profile.patient.gender!),
                  // Ch. 5  -  "Outstanding amount if applicable": only
                  // shown when the patient actually owes something, so
                  // a fully-settled patient's profile stays uncluttered.
                  if (profile.outstandingBalance > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.outstandingPaymentsLabel}: ${profile.outstandingBalance.toStringAsFixed(0)} DZD',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => _addToQueue(context, ref),
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(l10n.addToQueueAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.visitHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            if (profile.visits.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(child: Text(l10n.noVisitsYetMessage)),
              )
            else
              ...profile.visits.map(
                (visit) => Container(
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
                        children: [
                          Expanded(
                            child: Text(
                              '${visit.visitedAt.year}-${visit.visitedAt.month.toString().padLeft(2, '0')}-${visit.visitedAt.day.toString().padLeft(2, '0')}'
                              '${visit.doctorName != null ? ' · ${visit.doctorName}' : ''}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary),
                            ),
                          ),
                          if (visit.consultationPrice > 0)
                            IconButton(
                              icon: const Icon(Icons.receipt_outlined, size: 20),
                              tooltip: l10n.invoiceTitle,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClinicInvoiceViewScreen(visitId: visit.id),
                                ),
                              ),
                            ),
                          if (visit.consultationPrice > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _paymentStatusColor(visit.paymentStatus).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                              ),
                              child: Text(
                                _paymentStatusLabel(l10n, visit.paymentStatus),
                                style: TextStyle(
                                  color: _paymentStatusColor(visit.paymentStatus),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (visit.reason != null) Text(visit.reason!),
                      if (visit.diagnosis != null) Text('${l10n.diagnosisLabel}: ${visit.diagnosis}'),
                      if (visit.treatment != null) Text('${l10n.treatmentLabel}: ${visit.treatment}'),
                      if (visit.prescription != null) Text('${l10n.prescriptionLabel}: ${visit.prescription}'),
                      if (visit.consultationPrice > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${l10n.consultationPriceLabel}: ${visit.consultationPrice.toStringAsFixed(0)} DZD'
                          '  ·  ${l10n.amountPaidLabel}: ${visit.amountPaid.toStringAsFixed(0)} DZD',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (visit.remaining > 0 && visit.paymentStatus != ClinicPaymentStatus.refunded)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: OutlinedButton.icon(
                              onPressed: () => _recordPayment(context, ref, visit),
                              icon: const Icon(Icons.payments_outlined, size: 18),
                              label: Text(l10n.clinicRecordPaymentAction),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.documentsTitle, style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () => _addDocument(context, ref),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(l10n.addDocumentAction),
                ),
              ],
            ),
            if (profile.documents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(child: Text(l10n.noDocumentsYetMessage)),
              )
            else
              ...profile.documents.map(
                (doc) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: InkWell(
                    onTap: () => _previewDocument(context, ref, doc),
                    child: Row(
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.fileName, style: Theme.of(context).textTheme.titleSmall),
                            Text(
                              [
                                if (doc.documentType != null) doc.documentType!,
                                _formatDate(doc.uploadedAt),
                                if (doc.uploadedByName != null) doc.uploadedByName!,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (doc.description != null) Text(doc.description!),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => _deleteDocument(context, ref, doc),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.prescriptionsTitle, style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () => _openNewPrescription(context, ref),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(l10n.newPrescriptionAction),
                ),
              ],
            ),
            if (profile.prescriptions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(child: Text(l10n.noPrescriptionsYetMessage)),
              )
            else
              ...profile.prescriptions.map(
                (rx) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClinicPrescriptionFormScreen(
                          patientId: patientId,
                          viewOnlyPrescriptionId: rx.id,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rx.prescriptionNumber} — ${_formatDate(rx.issuedAt)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary),
                        ),
                        Text(
                          rx.items.map((i) => i.medicationName).join(', '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.networkError)),
      ),
    );
  }
}

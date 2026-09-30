import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
// FIX: this pointed at a same-directory 'clinic_models.dart' that does
// not exist (the models actually live in ../domain/) — a pre-existing
// broken import that would have failed at compile time the moment
// anything here actually got analyzed/built.
import '../domain/clinic_models.dart';

class ClinicRepository {
  ClinicRepository(this._ref);
  final Ref _ref;

  Future<ClinicDashboardStats> dashboard() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/clinic/dashboard');
    return ClinicDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<ClinicPatient>> listPatients({String? search}) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get(
      '/clinic/patients',
      query: search != null && search.isNotEmpty ? {'search': search} : null,
    );
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(ClinicPatient.fromJson).toList();
  }

  Future<ClinicPatient> createPatient({
    required String fullName,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
    String? notes,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/clinic/patients', body: {
      'fullName': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String().substring(0, 10),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return ClinicPatient.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<ClinicPatientProfile> patientProfile(String patientId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/clinic/patients/$patientId');
    return ClinicPatientProfile.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<({List<ClinicQueueEntry> queue, String? nextPatient})> queue() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/clinic/queue');
    final data = response['data'] as Map<String, dynamic>;
    final rows = (data['queue'] as List).cast<Map<String, dynamic>>();
    return (
      queue: rows.map(ClinicQueueEntry.fromJson).toList(),
      nextPatient: data['nextPatient'] as String?,
    );
  }

  Future<void> addToQueue({required String patientId, String? visitType}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/clinic/queue', body: {
      'patientId': patientId,
      if (visitType != null && visitType.isNotEmpty) 'visitType': visitType,
    });
  }

  Future<void> callNextPatient() async {
    final client = _ref.read(apiClientProvider);
    await client.post('/clinic/queue/call-next');
  }

  Future<void> completeConsultation(
    String queueId, {
    String? diagnosis,
    String? treatment,
    String? prescription,
    String? notes,
    double? consultationPrice,
    double? amountPaid,
    String? paymentMethod,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/clinic/queue/$queueId/complete', body: {
      if (diagnosis != null && diagnosis.isNotEmpty) 'diagnosis': diagnosis,
      if (treatment != null && treatment.isNotEmpty) 'treatment': treatment,
      if (prescription != null && prescription.isNotEmpty) 'prescription': prescription,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      // Ch. 7 — the consultation price and, if the patient paid on the
      // spot, that first payment (recorded as a real ledger entry
      // server-side, never a raw column write).
      if (consultationPrice != null) 'consultationPrice': consultationPrice,
      if (amountPaid != null && amountPaid > 0) 'amountPaid': amountPaid,
      if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
    });
  }

  Future<void> cancelQueueEntry(String queueId) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/clinic/queue/$queueId/cancel');
  }

  /// Ch. 7/8 — record a payment (full or partial) against a visit.
  Future<void> recordPayment(
    String visitId, {
    required double amount,
    String? method,
    String? note,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/clinic/visits/$visitId/payments', body: {
      'amount': amount,
      if (method != null && method.isNotEmpty) 'method': method,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Ch. 8 — refund everything paid so far on this visit.
  Future<void> refundVisit(String visitId, {String? note}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/clinic/visits/$visitId/refund', body: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Ch. 4 (remaining-issues pass) — real binary upload: base64-encodes
  /// [bytes] client-side and sends them in the JSON body, the same
  /// pattern the AI Invoice Scanner already uses to send a photo to
  /// this backend (see api_client's body-limit history) — reused
  /// rather than introducing a second, multipart-based upload path.
  /// fileSize/fileType are no longer sent — the backend computes both
  /// itself from the real decoded bytes.
  Future<ClinicDocument> addDocument({
    required String patientId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? documentType,
    String? description,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/clinic/documents', body: {
      'patientId': patientId,
      'fileName': fileName,
      'fileBase64': base64Encode(bytes),
      'mimeType': mimeType,
      if (documentType != null && documentType.isNotEmpty) 'documentType': documentType,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return ClinicDocument.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Fetches the raw bytes of a document for preview — always goes
  /// through this authenticated, company-scoped endpoint, never a raw
  /// stored URL (there isn't one anymore).
  Future<Uint8List> fetchDocumentBytes(String documentId) async {
    final client = _ref.read(apiClientProvider);
    return client.getBytes('/clinic/documents/$documentId/file');
  }

  Future<void> deleteDocument(String documentId) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/clinic/documents/$documentId');
  }

  /// Ch. 6 — create a prescription with one or more medication items.
  Future<ClinicPrescription> createPrescription({
    required String patientId,
    required List<ClinicPrescriptionItem> items,
    String? doctorId,
    String? visitId,
    String? notes,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/clinic/prescriptions', body: {
      'patientId': patientId,
      'items': items.map((i) => i.toJson()).toList(),
      if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
      if (visitId != null && visitId.isNotEmpty) 'visitId': visitId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return ClinicPrescription.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<ClinicPrescription> getPrescription(String prescriptionId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/clinic/prescriptions/$prescriptionId');
    return ClinicPrescription.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Ch. 7 — PDF bytes ready to hand to the `printing` package's print
  /// preview / share sheet (Printing.layoutPdf / Printing.sharePdf).
  Future<Uint8List> fetchPrescriptionPdf(String prescriptionId) async {
    final client = _ref.read(apiClientProvider);
    return client.getBytes('/clinic/prescriptions/$prescriptionId/pdf');
  }

  /// Ch. 8 — computed, read-only invoice view over the visit+payment
  /// ledger (no separate clinic invoice entity — see backend
  /// clinic.service.getVisitInvoice for why).
  Future<ClinicInvoice> getVisitInvoice(String visitId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/clinic/visits/$visitId/invoice');
    return ClinicInvoice.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Ch. 9 — PDF bytes for the same computed invoice.
  Future<Uint8List> fetchVisitInvoicePdf(String visitId) async {
    final client = _ref.read(apiClientProvider);
    return client.getBytes('/clinic/visits/$visitId/invoice/pdf');
  }
}

final clinicRepositoryProvider = Provider<ClinicRepository>((ref) => ClinicRepository(ref));

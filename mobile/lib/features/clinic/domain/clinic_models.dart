// Clinic specialized module domain models (Ch. 3). Kept in one file
// since they're small and always used together, matching this
// codebase's existing pattern for simpler features (e.g. Customer
// living directly inside customers_screen.dart).

/// Postgres NUMERIC columns (consultation_price, amount_paid, every
/// revenue figure below) come back over JSON as strings, not numbers —
/// parsed centrally here so every model below stays a one-line call
/// instead of repeating the same num-or-string branch.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class ClinicPatient {
  ClinicPatient({
    required this.id,
    required this.fullName,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.email,
    this.notes,
  });

  final String id;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? phone;
  final String? email;
  final String? notes;

  factory ClinicPatient.fromJson(Map<String, dynamic> json) => ClinicPatient(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth']) : null,
        gender: json['gender'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        notes: json['notes'] as String?,
      );
}

/// Ch. 8 — Paid / Partially paid / Unpaid / Refunded. Deliberately
/// never derived on the client: it always comes from the server's
/// clinic_payments ledger, the single source of truth (Ch. 21).
enum ClinicPaymentStatus { unpaid, partiallyPaid, paid, refunded }

ClinicPaymentStatus _paymentStatusFromJson(String? raw) => switch (raw) {
      'partially_paid' => ClinicPaymentStatus.partiallyPaid,
      'paid' => ClinicPaymentStatus.paid,
      'refunded' => ClinicPaymentStatus.refunded,
      _ => ClinicPaymentStatus.unpaid,
    };

class ClinicVisit {
  ClinicVisit({
    required this.id,
    required this.visitedAt,
    this.doctorName,
    this.reason,
    this.diagnosis,
    this.treatment,
    this.prescription,
    this.followUpDate,
    this.consultationPrice = 0,
    this.amountPaid = 0,
    this.paymentStatus = ClinicPaymentStatus.unpaid,
  });

  final String id;
  final DateTime visitedAt;
  final String? doctorName;
  final String? reason;
  final String? diagnosis;
  final String? treatment;
  final String? prescription;
  final DateTime? followUpDate;

  /// Ch. 7 — the consultation price, what was paid, and what's left.
  final double consultationPrice;
  final double amountPaid;
  final ClinicPaymentStatus paymentStatus;

  double get remaining => (consultationPrice - amountPaid).clamp(0, double.infinity);

  factory ClinicVisit.fromJson(Map<String, dynamic> json) => ClinicVisit(
        id: json['id'] as String,
        visitedAt: DateTime.parse(json['visited_at'] as String),
        doctorName: json['doctor_name'] as String?,
        reason: json['reason'] as String?,
        diagnosis: json['diagnosis'] as String?,
        treatment: json['treatment'] as String?,
        prescription: json['prescription'] as String?,
        followUpDate: json['follow_up_date'] != null ? DateTime.tryParse(json['follow_up_date']) : null,
        consultationPrice: _toDouble(json['consultation_price']),
        amountPaid: _toDouble(json['amount_paid']),
        paymentStatus: _paymentStatusFromJson(json['payment_status'] as String?),
      );
}

/// One line of the consultation payment ledger (Ch. 5's "Payments" on
/// the patient profile) — a negative [amount] is a refund.
class ClinicPayment {
  ClinicPayment({
    required this.id,
    required this.visitId,
    required this.amount,
    required this.paidAt,
    this.method,
    this.note,
  });

  final String id;
  final String visitId;
  final double amount;
  final DateTime paidAt;
  final String? method;
  final String? note;

  factory ClinicPayment.fromJson(Map<String, dynamic> json) => ClinicPayment(
        id: json['id'] as String,
        visitId: json['visit_id'] as String,
        amount: _toDouble(json['amount']),
        paidAt: DateTime.parse(json['paid_at'] as String),
        method: json['method'] as String?,
        note: json['note'] as String?,
      );
}

/// Ch. 4 — one uploaded medical document (PDF report, analysis,
/// prescription scan, ...). File content itself is stored elsewhere
/// (fileUrl only — this app has no binary upload storage service wired
/// up yet, see migration 017/022's notes); what's modeled here is the
/// metadata the spec asks for: who uploaded it, when, how big, what type.
class ClinicDocument {
  ClinicDocument({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
    this.documentType,
    this.description,
    this.fileSize,
    this.fileType,
    this.uploadedByName,
  });

  final String id;
  final String fileName;
  final String fileUrl;
  final DateTime uploadedAt;
  final String? documentType;
  final String? description;
  final int? fileSize;
  final String? fileType;
  final String? uploadedByName;

  factory ClinicDocument.fromJson(Map<String, dynamic> json) => ClinicDocument(
        id: json['id'] as String,
        fileName: json['file_name'] as String,
        fileUrl: json['file_url'] as String,
        uploadedAt: DateTime.parse(json['uploaded_at'] as String),
        documentType: json['document_type'] as String?,
        description: json['description'] as String?,
        fileSize: json['file_size'] != null ? int.tryParse(json['file_size'].toString()) : null,
        fileType: json['file_type'] as String?,
        uploadedByName: json['uploaded_by_name'] as String?,
      );
}

/// Ch. 6 — one line (medication) inside a prescription.
class ClinicPrescriptionItem {
  ClinicPrescriptionItem({
    required this.medicationName,
    this.dosage,
    this.quantity,
    this.frequency,
    this.duration,
    this.instructions,
  });

  final String medicationName;
  final String? dosage;
  final String? quantity;
  final String? frequency;
  final String? duration;
  final String? instructions;

  factory ClinicPrescriptionItem.fromJson(Map<String, dynamic> json) => ClinicPrescriptionItem(
        medicationName: json['medication_name'] as String,
        dosage: json['dosage'] as String?,
        quantity: json['quantity'] as String?,
        frequency: json['frequency'] as String?,
        duration: json['duration'] as String?,
        instructions: json['instructions'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'medicationName': medicationName,
        if (dosage != null && dosage!.isNotEmpty) 'dosage': dosage,
        if (quantity != null && quantity!.isNotEmpty) 'quantity': quantity,
        if (frequency != null && frequency!.isNotEmpty) 'frequency': frequency,
        if (duration != null && duration!.isNotEmpty) 'duration': duration,
        if (instructions != null && instructions!.isNotEmpty) 'instructions': instructions,
      };
}

/// Ch. 6 — a full prescription/ordonnance: patient + doctor + date +
/// one or more medication items, with a unique prescriptionNumber
/// ("RX-<n>", same per-company sequential pattern as invoice numbers).
class ClinicPrescription {
  ClinicPrescription({
    required this.id,
    required this.prescriptionNumber,
    required this.issuedAt,
    required this.items,
    this.doctorName,
    this.patientName,
    this.notes,
  });

  final String id;
  final String prescriptionNumber;
  final DateTime issuedAt;
  final List<ClinicPrescriptionItem> items;
  final String? doctorName;
  final String? patientName;
  final String? notes;

  factory ClinicPrescription.fromJson(Map<String, dynamic> json) => ClinicPrescription(
        id: json['id'] as String,
        prescriptionNumber: json['prescription_number'] as String,
        issuedAt: DateTime.parse(json['issued_at'] as String),
        items: (json['items'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClinicPrescriptionItem.fromJson)
            .toList(),
        doctorName: json['doctor_name'] as String?,
        patientName: json['patient_name'] as String?,
        notes: json['notes'] as String?,
      );
}

/// Ch. 8/9 — computed, read-only invoice view (GET /clinic/visits/:id/invoice).
/// Not a stored entity — see backend clinic.service.getVisitInvoice.
class ClinicInvoice {
  ClinicInvoice({
    required this.invoiceNumber,
    required this.date,
    required this.patientName,
    required this.serviceLabel,
    required this.consultationPrice,
    required this.amountPaid,
    required this.remaining,
    required this.paymentStatus,
    this.patientPhone,
  });

  final String invoiceNumber;
  final DateTime date;
  final String patientName;
  final String? patientPhone;
  final String serviceLabel;
  final double consultationPrice;
  final double amountPaid;
  final double remaining;
  final String paymentStatus;

  factory ClinicInvoice.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>? ?? {};
    return ClinicInvoice(
      invoiceNumber: json['invoiceNumber'] as String,
      date: DateTime.parse(json['date'] as String),
      patientName: patient['fullName'] as String? ?? '',
      patientPhone: patient['phone'] as String?,
      serviceLabel: json['serviceLabel'] as String? ?? '',
      consultationPrice: _toDouble(json['consultationPrice']),
      amountPaid: _toDouble(json['amountPaid']),
      remaining: _toDouble(json['remaining']),
      paymentStatus: json['paymentStatus'] as String? ?? 'unpaid',
    );
  }
}

class ClinicPatientProfile {
  ClinicPatientProfile({
    required this.patient,
    required this.visits,
    this.payments = const [],
    this.documents = const [],
    this.prescriptions = const [],
    this.outstandingBalance = 0,
  });

  final ClinicPatient patient;
  final List<ClinicVisit> visits;
  final List<ClinicPayment> payments;
  final List<ClinicDocument> documents;
  final List<ClinicPrescription> prescriptions;

  /// Ch. 5 — "Outstanding amount if applicable", summed server-side
  /// from this same patient's unpaid/partially-paid visits.
  final double outstandingBalance;

  factory ClinicPatientProfile.fromJson(Map<String, dynamic> json) => ClinicPatientProfile(
        patient: ClinicPatient.fromJson(json),
        visits: (json['visits'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClinicVisit.fromJson)
            .toList(),
        payments: (json['payments'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClinicPayment.fromJson)
            .toList(),
        documents: (json['documents'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClinicDocument.fromJson)
            .toList(),
        prescriptions: (json['prescriptions'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClinicPrescription.fromJson)
            .toList(),
        outstandingBalance: _toDouble(json['outstandingBalance']),
      );
}

enum ClinicQueueStatus { waiting, next, inConsultation, completed, cancelled }

ClinicQueueStatus _queueStatusFromJson(String raw) => switch (raw) {
      'next' => ClinicQueueStatus.next,
      'in_consultation' => ClinicQueueStatus.inConsultation,
      'completed' => ClinicQueueStatus.completed,
      'cancelled' => ClinicQueueStatus.cancelled,
      _ => ClinicQueueStatus.waiting,
    };

class ClinicQueueEntry {
  ClinicQueueEntry({
    required this.id,
    required this.position,
    required this.patientName,
    required this.status,
    this.doctorName,
    this.visitType,
  });

  final String id;
  final int position;
  final String patientName;
  final ClinicQueueStatus status;
  final String? doctorName;
  final String? visitType;

  factory ClinicQueueEntry.fromJson(Map<String, dynamic> json) => ClinicQueueEntry(
        id: json['id'] as String,
        position: json['position'] as int,
        patientName: json['patient_name'] as String,
        status: _queueStatusFromJson(json['status'] as String),
        doctorName: json['doctor_name'] as String?,
        visitType: json['visit_type'] as String?,
      );
}

class ClinicDashboardStats {
  ClinicDashboardStats({
    required this.patientsToday,
    required this.appointmentsToday,
    required this.waitingCount,
    required this.completedToday,
    required this.noShowToday,
    required this.newPatientsToday,
    required this.doctorCount,
    this.todayRevenue = 0,
    this.weekRevenue = 0,
    this.monthRevenue = 0,
    this.todayExpenses = 0,
    this.todayProfit = 0,
    this.outstandingPayments = 0,
  });

  final int patientsToday;
  final int appointmentsToday;
  final int waitingCount;
  final int completedToday;
  final int noShowToday;
  final int newPatientsToday;
  final int doctorCount;

  /// Ch. 9-11 — revenue = actual patient payments, never product
  /// sales; profit = revenue - clinic expenses.
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final double todayExpenses;
  final double todayProfit;
  final double outstandingPayments;

  factory ClinicDashboardStats.fromJson(Map<String, dynamic> json) => ClinicDashboardStats(
        patientsToday: json['patientsToday'] as int,
        appointmentsToday: json['appointmentsToday'] as int,
        waitingCount: json['waitingCount'] as int,
        completedToday: json['completedToday'] as int,
        noShowToday: json['noShowToday'] as int,
        newPatientsToday: json['newPatientsToday'] as int,
        doctorCount: json['doctorCount'] as int,
        todayRevenue: _toDouble(json['todayRevenue']),
        weekRevenue: _toDouble(json['weekRevenue']),
        monthRevenue: _toDouble(json['monthRevenue']),
        todayExpenses: _toDouble(json['todayExpenses']),
        todayProfit: _toDouble(json['todayProfit']),
        outstandingPayments: _toDouble(json['outstandingPayments']),
      );
}

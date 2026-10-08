const repo = require('./clinic.repository');
const expensesRepo = require('../expenses/expenses.repository');
const employeesRepo = require('../employees/employees.repository');
const { query } = require('../../config/db');
const fileStorage = require('../../utils/fileStorage');
const pdfService = require('../../utils/pdf.service');
const ApiError = require('../../utils/ApiError');

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

async function requirePatient(companyId, patientId) {
  const patient = await repo.findPatientById(companyId, patientId);
  if (!patient) {
    throw ApiError.notFound('Patient not found');
  }
  return patient;
}

// ---------------------------------------------------------------------
// Patients
// ---------------------------------------------------------------------

async function createPatient(companyId, data) {
  const fullName = (data.fullName || data.name || '').trim();
  if (!fullName) {
    throw ApiError.badRequest('fullName is required', 'VALIDATION_ERROR');
  }
  const created = await repo.createPatient(companyId, { ...data, fullName });
  return {
    ...created,
    name: created.full_name,
    fullName: created.full_name,
    birthDate: created.date_of_birth,
  };
}

async function updatePatient(companyId, patientId, data) {
  await requirePatient(companyId, patientId);
  const updated = await repo.updatePatient(companyId, patientId, data);
  return {
    ...updated,
    name: updated.full_name,
    fullName: updated.full_name,
    birthDate: updated.date_of_birth,
  };
}

async function deletePatient(companyId, patientId) {
  await requirePatient(companyId, patientId);
  return repo.deletePatient(companyId, patientId);
}

async function listPatients(companyId, search) {
  const list = await repo.findAllPatients(companyId, search);
  return list.map((p) => ({
    ...p,
    name: p.full_name,
    fullName: p.full_name,
    birthDate: p.date_of_birth,
  }));
}

/**
 * The full Patient Profile (Ch. 3.C): personal info + visit history +
 * documents in one response, so the Flutter screen doesn't need three
 * round trips just to render one profile page.
 */
async function getPatientProfile(companyId, patientId) {
  const patient = await requirePatient(companyId, patientId);
  const [visits, documents, payments, prescriptions] = await Promise.all([
    repo.findVisitsByPatient(companyId, patientId),
    repo.findDocumentsByPatient(companyId, patientId),
    repo.findPaymentsByPatient(companyId, patientId),
    repo.findPrescriptionsByPatient(companyId, patientId),
  ]);

  // Ch. 5's "Outstanding amount if applicable" — summed straight from
  // the same per-visit price/paid snapshot the dashboard uses, so this
  // number and the dashboard's outstandingPayments total can never
  // disagree about what one patient owes.
  const outstandingBalance = visits.reduce((sum, v) => {
    if (v.payment_status === 'unpaid' || v.payment_status === 'partially_paid') {
      return sum + (Number(v.consultation_price) - Number(v.amount_paid));
    }
    return sum;
  }, 0);

  const normalizedPatient = {
    ...patient,
    name: patient.full_name,
    fullName: patient.full_name,
    birthDate: patient.date_of_birth,
  };

  return {
    ...normalizedPatient,
    patient: normalizedPatient,
    records: visits,
    visits,
    documents,
    payments,
    prescriptions,
    outstandingBalance,
  };
}

// ---------------------------------------------------------------------
// Appointments
// ---------------------------------------------------------------------

async function createAppointment(companyId, data) {
  await requirePatient(companyId, data.patientId);

  if (!data.scheduledAt) {
    throw ApiError.badRequest('scheduledAt is required', 'VALIDATION_ERROR');
  }

  return repo.createAppointment(companyId, data);
}

async function listAppointments(companyId, range) {
  return repo.findAppointments(companyId, range);
}

const VALID_APPOINTMENT_STATUSES = [
  'scheduled', 'confirmed', 'waiting', 'in_consultation', 'completed', 'cancelled', 'no_show',
];

async function updateAppointmentStatus(companyId, id, status) {
  if (!VALID_APPOINTMENT_STATUSES.includes(status)) {
    throw ApiError.badRequest(
      `status must be one of: ${VALID_APPOINTMENT_STATUSES.join(', ')}`,
      'VALIDATION_ERROR',
    );
  }
  const updated = await repo.updateAppointmentStatus(companyId, id, status);
  if (!updated) {
    throw ApiError.notFound('Appointment not found');
  }
  return updated;
}

// ---------------------------------------------------------------------
// Queue (Ch. 3.F)
// ---------------------------------------------------------------------

async function addToQueue(companyId, data) {
  await requirePatient(companyId, data.patientId);
  try {
    return await repo.addToQueue(companyId, data);
  } catch (err) {
    if (err && err.code === 'PATIENT_ALREADY_IN_QUEUE') {
      throw ApiError.conflict(
        'This patient is already in the waiting queue',
        'PATIENT_ALREADY_IN_QUEUE',
      );
    }
    throw err;
  }
}

async function getQueue(companyId) {
  const entries = await repo.getActiveQueue(companyId);
  // "Next Patient: Sara" (Ch. 3.F example) — the first still-WAITING
  // entry, surfaced explicitly rather than making the client re-derive
  // it from the list.
  const nextUp = entries.find((e) => e.status === 'waiting') || null;
  return { queue: entries, nextPatient: nextUp ? nextUp.patient_name : null };
}

async function callNextPatient(companyId) {
  const called = await repo.callNextPatient(companyId);
  if (!called) {
    throw ApiError.badRequest('No patients are currently waiting', 'QUEUE_EMPTY');
  }
  return called;
}

/**
 * Marks a queue entry completed and — per Ch. 3.G/H, "these details are
 * saved inside Visit Record" — creates the corresponding visit record
 * in the same step, so a doctor finishing a consultation always leaves
 * exactly one visit behind, never zero (forgotten) or a second empty
 * one (duplicate).
 */
/**
 * visitData may include `consultationPrice` (Ch. 7 — required to know
 * what's owed at all) and `amountPaid` (Ch. 7's "patient paid at time
 * of consultation" case) — amountPaid is recorded as a real
 * clinic_payments ledger entry via recordPayment, never written
 * directly onto the visit row, so it's indistinguishable from any
 * other payment recorded later.
 */
async function completeConsultation(companyId, queueId, visitData) {
  const entry = await repo.findQueueEntryById(companyId, queueId);
  if (!entry) {
    throw ApiError.notFound('Queue entry not found');
  }

  const { amountPaid, paymentMethod, ...visitFields } = visitData || {};

  const visit = await repo.createVisit(companyId, {
    patientId: entry.patient_id,
    doctorId: entry.doctor_id,
    appointmentId: entry.appointment_id,
    ...visitFields,
  });

  await repo.completeQueueEntry(companyId, queueId);

  if (entry.appointment_id) {
    await repo.updateAppointmentStatus(companyId, entry.appointment_id, 'completed');
  }

  if (amountPaid && Number(amountPaid) > 0) {
    const result = await repo.recordPayment(companyId, visit.id, {
      amount: amountPaid,
      method: paymentMethod,
    });
    return result.visit;
  }

  return visit;
}

// ---------------------------------------------------------------------
// Consultation Payments (Ch. 7-11)
// ---------------------------------------------------------------------

async function requireVisit(companyId, visitId) {
  const visit = await repo.findVisitById(companyId, visitId);
  if (!visit) {
    throw ApiError.notFound('Visit not found');
  }
  return visit;
}

async function recordPayment(companyId, visitId, data) {
  await requireVisit(companyId, visitId);

  const amount = Number(data.amount);
  if (!amount || amount <= 0) {
    throw ApiError.badRequest('amount must be a positive number', 'VALIDATION_ERROR');
  }

  const result = await repo.recordPayment(companyId, visitId, {
    amount,
    method: data.method,
    note: data.note,
    paidAt: data.paidAt,
  });

  if (!result) {
    throw ApiError.notFound('Visit not found');
  }

  return result;
}

async function refundVisit(companyId, visitId, note) {
  await requireVisit(companyId, visitId);
  const result = await repo.refundVisit(companyId, visitId, note);
  if (!result) {
    throw ApiError.badRequest('This visit has no payment to refund', 'NOTHING_TO_REFUND');
  }
  return result;
}

async function cancelQueueEntry(companyId, queueId) {
  const cancelled = await repo.cancelQueueEntry(companyId, queueId);
  if (!cancelled) {
    throw ApiError.notFound('Queue entry not found');
  }
  return cancelled;
}

// ---------------------------------------------------------------------
// Documents (Ch. 4)
// ---------------------------------------------------------------------

const MAX_DOCUMENT_SIZE_BYTES = 8 * 1024 * 1024; // 8 MB decoded (~10.7MB base64 — see app.js's 12mb JSON body limit)
const ALLOWED_DOCUMENT_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
]);

/** Ch. 4 — real binary storage (local disk, base64-in-JSON, same
 * pattern this app already uses for AI invoice-scan photos — see
 * fileStorage.js's header comment for why that pattern and not
 * multipart). Replaces the earlier "client supplies a fileUrl it hosts
 * itself" placeholder entirely; fileUrl is no longer accepted or
 * stored — file_size and file_type are now always computed
 * server-side from the actual decoded bytes, never trusted from the
 * client. */
async function addDocument(companyId, userId, data) {
  await requirePatient(companyId, data.patientId);

  if (typeof data.fileName !== 'string' || !data.fileName.trim()) {
    throw ApiError.badRequest('fileName is required', 'VALIDATION_ERROR');
  }
  if (typeof data.fileBase64 !== 'string' || !data.fileBase64) {
    throw ApiError.badRequest('fileBase64 is required', 'VALIDATION_ERROR');
  }
  if (!ALLOWED_DOCUMENT_TYPES.has(data.mimeType)) {
    throw ApiError.badRequest(
      'The uploaded file type is not supported. Allowed types: PDF, JPEG, PNG, WEBP.',
      'UNSUPPORTED_FILE_TYPE',
    );
  }

  let stored;
  try {
    stored = fileStorage.saveBase64File({
      namespace: 'clinic-documents',
      companyId,
      originalName: data.fileName,
      mimeType: data.mimeType,
      base64Data: data.fileBase64,
      maxBytes: MAX_DOCUMENT_SIZE_BYTES,
    });
  } catch (err) {
    if (err.code === 'FILE_TOO_LARGE') {
      throw ApiError.badRequest('The file is too large (max 8 MB)', 'FILE_TOO_LARGE');
    }
    if (err.code === 'UNSUPPORTED_FILE_TYPE' || err.code === 'INVALID_FILE_DATA') {
      throw ApiError.badRequest(err.message, err.code);
    }
    throw err;
  }

  return repo.addDocument(companyId, {
    patientId: data.patientId,
    visitId: data.visitId,
    fileName: data.fileName.trim(),
    fileUrl: stored.storageKey,
    fileSize: stored.fileSize,
    fileType: data.mimeType,
    documentType: data.documentType,
    description: data.description,
    uploadedBy: userId,
  });
}

async function deleteDocument(companyId, documentId) {
  const deleted = await repo.deleteDocument(companyId, documentId);
  if (!deleted) {
    throw ApiError.notFound('Document not found');
  }
  return deleted;
}

/** Ch. 4 "preview when supported / download" — resolves a document's
 * on-disk path ONLY after confirming it belongs to this company (the
 * same company_id-scoped lookup every other clinic query uses), so a
 * document can never be fetched by guessing an id across companies. */
async function getDocumentFile(companyId, documentId) {
  const doc = await repo.findDocumentById(companyId, documentId);
  if (!doc) {
    throw ApiError.notFound('Document not found');
  }
  return {
    absolutePath: fileStorage.resolveStoragePath(doc.file_url),
    fileName: doc.file_name,
    mimeType: doc.file_type,
  };
}

// ---------------------------------------------------------------------
// Patient invoices (Ch. 8/9) — computed view, not a stored document
// ---------------------------------------------------------------------

async function getCompany(companyId) {
  const result = await query(`SELECT name, phone, address FROM companies WHERE id = $1`, [companyId]);
  return result.rows[0] || {};
}

/**
 * Ch. 8 "Patient Invoices" — clinic intentionally has no separate
 * invoices table (018_add_clinic_consultation_payments.sql tracks
 * money directly on clinic_visits/clinic_payments, the same ledger
 * /clinic/dashboard, /dashboard and /reports all already read from).
 * Building a second, parallel invoice-document system here would be
 * exactly the "do not create duplicate functionality" the audit spec
 * warns against. Instead this is a READ-ONLY, computed view over that
 * same visit+payment data — an invoice number is derived deterministically
 * (never stored, never able to drift from the visit it represents), and
 * every amount is copied verbatim from the visit row so it is
 * impossible for this view, the PDF built from it, and clinic_visits
 * itself to ever disagree (Ch. 26 "Financial Consistency").
 */
async function getVisitInvoice(companyId, visitId) {
  const visit = await repo.findVisitById(companyId, visitId);
  if (!visit) {
    throw ApiError.notFound('Visit not found');
  }
  const patient = await repo.findPatientById(companyId, visit.patient_id);

  return {
    invoiceNumber: `CL-${visit.id.slice(0, 8).toUpperCase()}`,
    date: visit.visited_at,
    patient: { fullName: patient.full_name, phone: patient.phone },
    serviceLabel: visit.reason || 'Consultation',
    consultationPrice: Number(visit.consultation_price),
    amountPaid: Number(visit.amount_paid),
    remaining: Math.max(Number(visit.consultation_price) - Number(visit.amount_paid), 0),
    paymentStatus: visit.payment_status,
  };
}

async function streamVisitInvoicePdf(res, companyId, visitId) {
  const [company, invoice] = await Promise.all([
    getCompany(companyId),
    getVisitInvoice(companyId, visitId),
  ]);
  pdfService.streamClinicInvoicePdf(res, { company, invoice });
}

async function streamPrescriptionPdf(res, companyId, prescriptionId) {
  const prescription = await repo.findPrescriptionById(companyId, prescriptionId);
  if (!prescription) {
    throw ApiError.notFound('Prescription not found');
  }
  const [company, patient] = await Promise.all([
    getCompany(companyId),
    repo.findPatientById(companyId, prescription.patient_id),
  ]);
  pdfService.streamPrescriptionPdf(res, { company, patient, prescription });
}

// ---------------------------------------------------------------------
// Prescriptions (Ch. 6)
// ---------------------------------------------------------------------

async function createPrescription(companyId, userId, data) {
  await requirePatient(companyId, data.patientId);

  if (!Array.isArray(data.items) || data.items.length === 0) {
    throw ApiError.badRequest('At least one medication item is required', 'VALIDATION_ERROR');
  }
  for (const item of data.items) {
    if (typeof item.medicationName !== 'string' || !item.medicationName.trim()) {
      throw ApiError.badRequest('Each item requires a medicationName', 'VALIDATION_ERROR');
    }
  }

  return repo.createPrescription(companyId, { ...data, createdBy: userId });
}

async function getPrescription(companyId, prescriptionId) {
  const prescription = await repo.findPrescriptionById(companyId, prescriptionId);
  if (!prescription) {
    throw ApiError.notFound('Prescription not found');
  }
  return prescription;
}

// ---------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------

/**
 * Adds the financial half of the Clinic dashboard (Ch. 9-11) on top of
 * the existing patient/appointment counts: revenue is summed straight
 * from the clinic_payments ledger (never from product sales — there is
 * no such thing here), expenses are the same generic `expenses` module
 * every other business type already uses (Ch. 10 lists rent,
 * electricity, salaries, supplies — all ordinary expense categories,
 * not a clinic-only concept), and profit is exactly
 * PATIENT PAYMENTS - CLINIC EXPENSES, per Ch. 11.
 */
async function getDashboard(companyId) {
  const now = new Date();
  const todayStr = toDateStr(now);
  const weekStart = toDateStr(new Date(now.getTime() - 6 * 86400000));
  const monthStart = toDateStr(new Date(now.getFullYear(), now.getMonth(), 1));

  const [
    stats,
    todayRevenue,
    weekRevenue,
    monthRevenue,
    todayExpenses,
    todaySalaryCost,
    outstanding,
  ] = await Promise.all([
    repo.dashboardStats(companyId),
    repo.revenueForRange(companyId, todayStr, todayStr),
    repo.revenueForRange(companyId, weekStart, todayStr),
    repo.revenueForRange(companyId, monthStart, todayStr),
    expensesRepo.totalForRange(companyId, todayStr, todayStr),
    employeesRepo.totalSalaryCostForRange(companyId, todayStr, todayStr),
    repo.outstandingTotal(companyId),
  ]);

  const totalTodayExpenses = todayExpenses + todaySalaryCost;

  return {
    ...stats,
    todayRevenue,
    weekRevenue,
    monthRevenue,
    todayExpenses: totalTodayExpenses,
    todayOperatingExpenses: todayExpenses,
    todaySalaryCost,
    todayProfit: todayRevenue - totalTodayExpenses,
    outstandingPayments: outstanding,
  };
}

module.exports = {
  createPatient,
  updatePatient,
  deletePatient,
  listPatients,
  getPatientProfile,
  createAppointment,
  listAppointments,
  updateAppointmentStatus,
  addToQueue,
  getQueue,
  callNextPatient,
  completeConsultation,
  cancelQueueEntry,
  recordPayment,
  refundVisit,
  addDocument,
  deleteDocument,
  getDocumentFile,
  createPrescription,
  getPrescription,
  streamPrescriptionPdf,
  getVisitInvoice,
  streamVisitInvoicePdf,
  getDashboard,
};

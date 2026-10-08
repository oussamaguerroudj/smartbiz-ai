const { query, withTransaction } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function verifyDoctorBelongsToCompany(companyId, doctorId, client = null) {
  if (!doctorId) return;
  const runner = client ? client.query.bind(client) : query;
  const res = await runner(
    'SELECT id FROM employees WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
    [companyId, doctorId],
  );
  if (res.rows.length === 0) {
    throw ApiError.badRequest('Doctor/employee not found for this company', 'VALIDATION_ERROR');
  }
}

async function verifyAppointmentBelongsToCompany(companyId, appointmentId, client = null) {
  if (!appointmentId) return;
  const runner = client ? client.query.bind(client) : query;
  const res = await runner(
    'SELECT id FROM clinic_appointments WHERE company_id = $1 AND id = $2',
    [companyId, appointmentId],
  );
  if (res.rows.length === 0) {
    throw ApiError.badRequest('Appointment not found for this company', 'VALIDATION_ERROR');
  }
}

async function verifyVisitBelongsToCompany(companyId, visitId, client = null) {
  if (!visitId) return;
  const runner = client ? client.query.bind(client) : query;
  const res = await runner(
    'SELECT id FROM clinic_visits WHERE company_id = $1 AND id = $2',
    [companyId, visitId],
  );
  if (res.rows.length === 0) {
    throw ApiError.badRequest('Visit not found for this company', 'VALIDATION_ERROR');
  }
}

// ---------------------------------------------------------------------
// Patients
// ---------------------------------------------------------------------

async function createPatient(companyId, data) {
  await verifyDoctorBelongsToCompany(companyId, data.assignedDoctorId);
  const result = await query(
    `INSERT INTO clinic_patients (
       company_id, full_name, date_of_birth, gender, phone, email,
       address, emergency_contact, assigned_doctor_id, notes
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      companyId,
      data.fullName,
      data.dateOfBirth || null,
      data.gender || null,
      data.phone || null,
      data.email || null,
      data.address || null,
      data.emergencyContact || null,
      data.assignedDoctorId || null,
      data.notes || null,
    ],
  );
  return result.rows[0];
}

async function findAllPatients(companyId, search) {
  if (search) {
    const result = await query(
      `SELECT * FROM clinic_patients
       WHERE company_id = $1 AND deleted_at IS NULL
         AND (full_name ILIKE $2 OR phone ILIKE $2)
       ORDER BY full_name`,
      [companyId, `%${search}%`],
    );
    return result.rows;
  }
  const result = await query(
    `SELECT * FROM clinic_patients WHERE company_id = $1 AND deleted_at IS NULL ORDER BY full_name`,
    [companyId],
  );
  return result.rows;
}

async function findPatientById(companyId, id) {
  const result = await query(
    `SELECT * FROM clinic_patients WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function updatePatient(companyId, id, data) {
  const fullName = data.fullName || data.name;
  const result = await query(
    `UPDATE clinic_patients
     SET full_name = COALESCE($3, full_name),
         date_of_birth = COALESCE($4, date_of_birth),
         gender = COALESCE($5, gender),
         phone = COALESCE($6, phone),
         email = COALESCE($7, email),
         address = COALESCE($8, address),
         emergency_contact = COALESCE($9, emergency_contact),
         notes = COALESCE($10, notes),
         updated_at = NOW()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      id,
      fullName || null,
      data.dateOfBirth || data.birthDate || null,
      data.gender || null,
      data.phone || null,
      data.email || null,
      data.address || null,
      data.emergencyContact || null,
      data.notes || null,
    ],
  );
  return result.rows[0] || null;
}

async function deletePatient(companyId, id) {
  const result = await query(
    `UPDATE clinic_patients
     SET deleted_at = NOW()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Appointments
// ---------------------------------------------------------------------

async function createAppointment(companyId, data) {
  await verifyDoctorBelongsToCompany(companyId, data.doctorId);
  const result = await query(
    `INSERT INTO clinic_appointments (
       company_id, patient_id, doctor_id, scheduled_at, appointment_type, notes
     )
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [companyId, data.patientId, data.doctorId || null, data.scheduledAt, data.appointmentType || null, data.notes || null],
  );
  return result.rows[0];
}

async function findAppointments(companyId, { from, to } = {}) {
  if (from && to) {
    const result = await query(
      `SELECT ca.*, cp.full_name AS patient_name
       FROM clinic_appointments ca
       JOIN clinic_patients cp ON cp.id = ca.patient_id AND cp.company_id = ca.company_id
       WHERE ca.company_id = $1 AND ca.scheduled_at BETWEEN $2 AND $3
       ORDER BY ca.scheduled_at`,
      [companyId, from, to],
    );
    return result.rows;
  }
  const result = await query(
    `SELECT ca.*, cp.full_name AS patient_name
     FROM clinic_appointments ca
     JOIN clinic_patients cp ON cp.id = ca.patient_id AND cp.company_id = ca.company_id
     WHERE ca.company_id = $1
     ORDER BY ca.scheduled_at DESC
     LIMIT 100`,
    [companyId],
  );
  return result.rows;
}

async function updateAppointmentStatus(companyId, id, status) {
  const result = await query(
    `UPDATE clinic_appointments SET status = $3 WHERE company_id = $1 AND id = $2 RETURNING *`,
    [companyId, id, status],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Queue (Ch. 3.F)
// ---------------------------------------------------------------------

async function nextQueuePosition(client, companyId) {
  const result = await client.query(
    `SELECT COALESCE(MAX(position), 0) + 1 AS next_position
     FROM clinic_queue
     WHERE company_id = $1 AND arrived_at::date = CURRENT_DATE`,
    [companyId],
  );
  return result.rows[0].next_position;
}

async function findActiveQueueEntryForPatient(client, companyId, patientId) {
  const result = await client.query(
    `SELECT * FROM clinic_queue
     WHERE company_id = $1 AND patient_id = $2
       AND arrived_at::date = CURRENT_DATE
       AND status IN ('waiting', 'next', 'in_consultation')
     FOR UPDATE`,
    [companyId, patientId],
  );
  return result.rows[0] || null;
}

async function addToQueue(companyId, { patientId, appointmentId, doctorId, visitType }) {
  return withTransaction(async (client) => {
    await verifyDoctorBelongsToCompany(companyId, doctorId, client);
    await verifyAppointmentBelongsToCompany(companyId, appointmentId, client);

    const existing = await findActiveQueueEntryForPatient(client, companyId, patientId);
    if (existing) {
      const err = new Error('PATIENT_ALREADY_IN_QUEUE');
      err.code = 'PATIENT_ALREADY_IN_QUEUE';
      err.existingEntry = existing;
      throw err;
    }

    const position = await nextQueuePosition(client, companyId);
    const result = await client.query(
      `INSERT INTO clinic_queue (company_id, patient_id, appointment_id, doctor_id, position, visit_type)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [companyId, patientId, appointmentId || null, doctorId || null, position, visitType || null],
    );

    if (appointmentId) {
      await client.query(
        `UPDATE clinic_appointments SET status = 'waiting' WHERE company_id = $1 AND id = $2`,
        [companyId, appointmentId],
      );
    }

    return result.rows[0];
  });
}

/** Today's queue, ordered for display exactly like the spec's example (#01 Ahmed  -  Waiting...). */
async function getActiveQueue(companyId) {
  const result = await query(
    `SELECT cq.*, cp.full_name AS patient_name, e.name AS doctor_name
     FROM clinic_queue cq
     JOIN clinic_patients cp ON cp.id = cq.patient_id AND cp.company_id = cq.company_id
     LEFT JOIN employees e ON e.id = cq.doctor_id AND e.company_id = cq.company_id
     WHERE cq.company_id = $1
       AND cq.arrived_at::date = CURRENT_DATE
       AND cq.status IN ('waiting', 'next', 'in_consultation')
     ORDER BY cq.position ASC`,
    [companyId],
  );
  return result.rows;
}

async function callNextPatient(companyId) {
  return withTransaction(async (client) => {
    const nextResult = await client.query(
      `SELECT * FROM clinic_queue
       WHERE company_id = $1 AND arrived_at::date = CURRENT_DATE AND status = 'waiting'
       ORDER BY position ASC
       LIMIT 1
       FOR UPDATE`,
      [companyId],
    );

    const next = nextResult.rows[0];
    if (!next) return null;

    const updated = await client.query(
      `UPDATE clinic_queue
       SET status = 'in_consultation', called_at = now()
       WHERE id = $1 AND company_id = $2
       RETURNING *`,
      [next.id, companyId],
    );

    if (next.appointment_id) {
      await client.query(
        `UPDATE clinic_appointments SET status = 'in_consultation' WHERE id = $1 AND company_id = $2`,
        [next.appointment_id, companyId],
      );
    }

    return updated.rows[0];
  });
}

async function completeQueueEntry(companyId, queueId) {
  const result = await query(
    `UPDATE clinic_queue
     SET status = 'completed', completed_at = now()
     WHERE company_id = $1 AND id = $2
     RETURNING *`,
    [companyId, queueId],
  );
  return result.rows[0] || null;
}

async function cancelQueueEntry(companyId, queueId) {
  const result = await query(
    `UPDATE clinic_queue SET status = 'cancelled' WHERE company_id = $1 AND id = $2 RETURNING *`,
    [companyId, queueId],
  );
  return result.rows[0] || null;
}

async function findQueueEntryById(companyId, queueId) {
  const result = await query(
    `SELECT * FROM clinic_queue WHERE company_id = $1 AND id = $2`,
    [companyId, queueId],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Visits (Ch. 3.H)
// ---------------------------------------------------------------------

async function createVisit(companyId, data) {
  await verifyDoctorBelongsToCompany(companyId, data.doctorId);
  await verifyAppointmentBelongsToCompany(companyId, data.appointmentId);
  const consultationPrice = Number(data.consultationPrice) || 0;
  const result = await query(
    `INSERT INTO clinic_visits (
       company_id, patient_id, doctor_id, appointment_id, reason,
       symptoms, diagnosis, treatment, prescription, notes, follow_up_date,
       consultation_price
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING *`,
    [
      companyId,
      data.patientId,
      data.doctorId || null,
      data.appointmentId || null,
      data.reason || null,
      data.symptoms || null,
      data.diagnosis || null,
      data.treatment || null,
      data.prescription || null,
      data.notes || null,
      data.followUpDate || null,
      consultationPrice,
    ],
  );
  return result.rows[0];
}

async function findVisitsByPatient(companyId, patientId) {
  const result = await query(
    `SELECT cv.*, e.name AS doctor_name
     FROM clinic_visits cv
     LEFT JOIN employees e ON e.id = cv.doctor_id AND e.company_id = cv.company_id
     WHERE cv.company_id = $1 AND cv.patient_id = $2
     ORDER BY cv.visited_at DESC`,
    [companyId, patientId],
  );
  return result.rows;
}

async function findVisitById(companyId, visitId) {
  const result = await query(
    `SELECT * FROM clinic_visits WHERE company_id = $1 AND id = $2`,
    [companyId, visitId],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Consultation Payments (Ch. 7-11  -  clinic revenue = patient payments,
// never product-sale logic; see 018_add_clinic_consultation_payments.sql)
// ---------------------------------------------------------------------

/** unpaid / partially_paid / paid, derived purely from the two numbers
 * on the visit  -  'refunded' is never derived here, only ever set
 * explicitly by refundVisit below, since it means something happened
 * (money went back out), not just "nothing paid yet". */
function derivePaymentStatus(consultationPrice, amountPaid) {
  const price = Number(consultationPrice);
  const paid = Number(amountPaid);
  if (paid <= 0) return 'unpaid';
  if (paid < price) return 'partially_paid';
  return 'paid';
}

/**
 * Records one payment against a visit and keeps clinic_visits'
 * denormalized amount_paid/payment_status in sync in the same
 * transaction, so every reader (queue, patient profile, dashboard)
 * always sees a consistent snapshot without re-summing the ledger.
 */
async function recordPayment(companyId, visitId, { amount, method, note, paidAt }) {
  return withTransaction(async (client) => {
    const visitResult = await client.query(
      `SELECT * FROM clinic_visits WHERE company_id = $1 AND id = $2 FOR UPDATE`,
      [companyId, visitId],
    );
    const visit = visitResult.rows[0];
    if (!visit) return null;

    const payment = await client.query(
      `INSERT INTO clinic_payments (company_id, visit_id, patient_id, amount, method, note, paid_at)
       VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7, now()))
       RETURNING *`,
      [companyId, visitId, visit.patient_id, amount, method || null, note || null, paidAt || null],
    );

    const newAmountPaid = Number(visit.amount_paid) + Number(amount);
    const newStatus = derivePaymentStatus(visit.consultation_price, newAmountPaid);

    const updatedVisit = await client.query(
      `UPDATE clinic_visits SET amount_paid = $3, payment_status = $4
       WHERE company_id = $1 AND id = $2
       RETURNING *`,
      [companyId, visitId, newAmountPaid, newStatus],
    );

    return { visit: updatedVisit.rows[0], payment: payment.rows[0] };
  });
}

/**
 * A full refund (Ch. 8's "Refunded" status): logs a negative ledger
 * line for whatever is currently paid, and forces payment_status to
 * 'refunded' explicitly rather than letting it fall back to 'unpaid'  - 
 * "never charged" and "charged then refunded" must stay distinguishable.
 */
async function refundVisit(companyId, visitId, note) {
  return withTransaction(async (client) => {
    const visitResult = await client.query(
      `SELECT * FROM clinic_visits WHERE company_id = $1 AND id = $2 FOR UPDATE`,
      [companyId, visitId],
    );
    const visit = visitResult.rows[0];
    if (!visit || Number(visit.amount_paid) <= 0) return null;

    const refundAmount = -Number(visit.amount_paid);

    const payment = await client.query(
      `INSERT INTO clinic_payments (company_id, visit_id, patient_id, amount, method, note)
       VALUES ($1, $2, $3, $4, 'refund', $5)
       RETURNING *`,
      [companyId, visitId, visit.patient_id, refundAmount, note || null],
    );

    const updatedVisit = await client.query(
      `UPDATE clinic_visits SET amount_paid = 0, payment_status = 'refunded'
       WHERE company_id = $1 AND id = $2
       RETURNING *`,
      [companyId, visitId],
    );

    return { visit: updatedVisit.rows[0], payment: payment.rows[0] };
  });
}

async function findPaymentsByPatient(companyId, patientId) {
  const result = await query(
    `SELECT * FROM clinic_payments WHERE company_id = $1 AND patient_id = $2 ORDER BY paid_at DESC`,
    [companyId, patientId],
  );
  return result.rows;
}

/** Net revenue actually collected in [rangeStart, rangeEnd] (inclusive
 * dates)  -  sums every clinic_payments row by paid_at, so a refund
 * (negative amount) correctly reduces the same day's revenue instead
 * of needing separate handling. */
async function revenueForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total FROM clinic_payments
     WHERE company_id = $1 AND paid_at::date BETWEEN $2::date AND $3::date`,
    [companyId, rangeStart, rangeEnd],
  );
  return Number(result.rows[0].total);
}

/** Total still owed across every unpaid/partially-paid visit (Ch. 9's
 * "Outstanding Patient Payments")  -  never includes refunded visits,
 * since a refund closes the visit out rather than leaving it owed. */
async function outstandingTotal(companyId) {
  const result = await query(
    `SELECT COALESCE(SUM(consultation_price - amount_paid), 0) AS total
     FROM clinic_visits
     WHERE company_id = $1 AND payment_status IN ('unpaid', 'partially_paid')`,
    [companyId],
  );
  return Number(result.rows[0].total);
}

// ---------------------------------------------------------------------
// Documents (Ch. 3.D)
// ---------------------------------------------------------------------

async function addDocument(companyId, data) {
  await verifyVisitBelongsToCompany(companyId, data.visitId);
  const result = await query(
    `INSERT INTO clinic_documents (
       company_id, patient_id, visit_id, file_name, file_url, document_type,
       description, file_size, file_type, uploaded_by
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      companyId,
      data.patientId,
      data.visitId || null,
      data.fileName,
      data.fileUrl,
      data.documentType || null,
      data.description || null,
      data.fileSize || null,
      data.fileType || null,
      data.uploadedBy || null,
    ],
  );
  return result.rows[0];
}

async function findDocumentsByPatient(companyId, patientId) {
  const result = await query(
    `SELECT cd.*, u.name AS uploaded_by_name
     FROM clinic_documents cd
     LEFT JOIN users u ON u.id = cd.uploaded_by AND u.company_id = cd.company_id
     WHERE cd.company_id = $1 AND cd.patient_id = $2 AND cd.deleted_at IS NULL
     ORDER BY cd.uploaded_at DESC`,
    [companyId, patientId],
  );
  return result.rows;
}

async function findDocumentById(companyId, documentId) {
  const result = await query(
    `SELECT * FROM clinic_documents WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, documentId],
  );
  return result.rows[0] || null;
}

async function deleteDocument(companyId, documentId) {
  const result = await query(
    `UPDATE clinic_documents SET deleted_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [companyId, documentId],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Prescriptions (Ch. 6)
// ---------------------------------------------------------------------

async function nextPrescriptionNumber(client, companyId) {
  const companyResult = await client.query(
    `SELECT id FROM companies WHERE id = $1 FOR UPDATE`,
    [companyId],
  );
  if (!companyResult.rows[0]) {
    throw new Error('Company not found while generating prescription number');
  }

  const result = await client.query(
    `SELECT COUNT(*)::int AS count FROM clinic_prescriptions WHERE company_id = $1`,
    [companyId],
  );

  return `RX-${result.rows[0].count + 1}`;
}

async function createPrescription(companyId, data) {
  return withTransaction(async (client) => {
    await verifyDoctorBelongsToCompany(companyId, data.doctorId, client);
    await verifyVisitBelongsToCompany(companyId, data.visitId, client);
    const prescriptionNumber = await nextPrescriptionNumber(client, companyId);

    const prescriptionResult = await client.query(
      `INSERT INTO clinic_prescriptions (
         company_id, patient_id, doctor_id, visit_id, prescription_number, notes, created_by
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        companyId,
        data.patientId,
        data.doctorId || null,
        data.visitId || null,
        prescriptionNumber,
        data.notes || null,
        data.createdBy || null,
      ],
    );
    const prescription = prescriptionResult.rows[0];

    const items = [];
    let sortOrder = 0;
    for (const item of data.items) {
      const itemResult = await client.query(
        `INSERT INTO clinic_prescription_items (
           prescription_id, medication_name, dosage, quantity, frequency, duration, instructions, sort_order
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          prescription.id,
          item.medicationName,
          item.dosage || null,
          item.quantity || null,
          item.frequency || null,
          item.duration || null,
          item.instructions || null,
          sortOrder,
        ],
      );
      items.push(itemResult.rows[0]);
      sortOrder += 1;
    }

    return { ...prescription, items };
  });
}

async function findPrescriptionsByPatient(companyId, patientId) {
  const result = await query(
    `SELECT cp.*, e.name AS doctor_name
     FROM clinic_prescriptions cp
     LEFT JOIN employees e ON e.id = cp.doctor_id AND e.company_id = cp.company_id
     WHERE cp.company_id = $1 AND cp.patient_id = $2
     ORDER BY cp.issued_at DESC`,
    [companyId, patientId],
  );
  return result.rows;
}

async function findPrescriptionById(companyId, prescriptionId) {
  const prescriptionResult = await query(
    `SELECT cp.*, e.name AS doctor_name, p.full_name AS patient_name
     FROM clinic_prescriptions cp
     LEFT JOIN employees e ON e.id = cp.doctor_id AND e.company_id = cp.company_id
     JOIN clinic_patients p ON p.id = cp.patient_id AND p.company_id = cp.company_id
     WHERE cp.company_id = $1 AND cp.id = $2`,
    [companyId, prescriptionId],
  );
  const prescription = prescriptionResult.rows[0];
  if (!prescription) return null;

  const itemsResult = await query(
    `SELECT * FROM clinic_prescription_items WHERE prescription_id = $1 ORDER BY sort_order ASC`,
    [prescriptionId],
  );

  return { ...prescription, items: itemsResult.rows };
}

// ---------------------------------------------------------------------
// Clinic Dashboard (Ch. 3.A)
// ---------------------------------------------------------------------

async function dashboardStats(companyId) {
  const [
    patientsToday,
    appointmentsToday,
    waiting,
    completedToday,
    noShowToday,
    newPatientsToday,
    doctorCount,
  ] = await Promise.all([
    query(
      `SELECT COUNT(DISTINCT patient_id)::int AS count FROM clinic_queue
       WHERE company_id = $1 AND arrived_at::date = CURRENT_DATE`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM clinic_appointments
       WHERE company_id = $1 AND scheduled_at::date = CURRENT_DATE`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM clinic_queue
       WHERE company_id = $1 AND arrived_at::date = CURRENT_DATE AND status = 'waiting'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM clinic_queue
       WHERE company_id = $1 AND arrived_at::date = CURRENT_DATE AND status = 'completed'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM clinic_appointments
       WHERE company_id = $1 AND scheduled_at::date = CURRENT_DATE AND status = 'no_show'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM clinic_patients
       WHERE company_id = $1 AND deleted_at IS NULL AND created_at::date = CURRENT_DATE`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM employees
       WHERE company_id = $1 AND deleted_at IS NULL AND position ILIKE '%doctor%'`,
      [companyId],
    ),
  ]);

  return {
    patientsToday: patientsToday.rows[0].count,
    appointmentsToday: appointmentsToday.rows[0].count,
    waitingCount: waiting.rows[0].count,
    completedToday: completedToday.rows[0].count,
    noShowToday: noShowToday.rows[0].count,
    newPatientsToday: newPatientsToday.rows[0].count,
    doctorCount: doctorCount.rows[0].count,
  };
}

module.exports = {
  createPatient,
  findAllPatients,
  findPatientById,
  updatePatient,
  deletePatient,
  createAppointment,
  findAppointments,
  updateAppointmentStatus,
  addToQueue,
  getActiveQueue,
  callNextPatient,
  completeQueueEntry,
  cancelQueueEntry,
  findQueueEntryById,
  createVisit,
  findVisitsByPatient,
  findVisitById,
  recordPayment,
  refundVisit,
  findPaymentsByPatient,
  revenueForRange,
  outstandingTotal,
  addDocument,
  findDocumentsByPatient,
  findDocumentById,
  deleteDocument,
  createPrescription,
  findPrescriptionsByPatient,
  findPrescriptionById,
  dashboardStats,
};

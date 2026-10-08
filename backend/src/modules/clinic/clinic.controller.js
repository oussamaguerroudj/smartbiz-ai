const asyncHandler = require('../../utils/asyncHandler');
const fs = require('fs');
const service = require('./clinic.service');

const createPatient = asyncHandler(async (req, res) => {
  const patient = await service.createPatient(req.user.companyId, req.body);
  res.status(201).json({ data: patient });
});

const listPatients = asyncHandler(async (req, res) => {
  const patients = await service.listPatients(req.user.companyId, req.query.search);
  res.json({ data: patients });
});

const getPatientProfile = asyncHandler(async (req, res) => {
  const profile = await service.getPatientProfile(req.user.companyId, req.params.id);
  res.json({ data: profile });
});

const updatePatient = asyncHandler(async (req, res) => {
  const updated = await service.updatePatient(req.user.companyId, req.params.id, req.body);
  res.json({ data: updated });
});

const deletePatient = asyncHandler(async (req, res) => {
  await service.deletePatient(req.user.companyId, req.params.id);
  res.json({ message: 'Patient removed successfully' });
});

const createAppointment = asyncHandler(async (req, res) => {
  const appointment = await service.createAppointment(req.user.companyId, req.body);
  res.status(201).json({ data: appointment });
});

const listAppointments = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const appointments = await service.listAppointments(req.user.companyId, from && to ? { from, to } : undefined);
  res.json({ data: appointments });
});

const updateAppointmentStatus = asyncHandler(async (req, res) => {
  const updated = await service.updateAppointmentStatus(req.user.companyId, req.params.id, req.body.status);
  res.json({ data: updated });
});

const addToQueue = asyncHandler(async (req, res) => {
  const entry = await service.addToQueue(req.user.companyId, req.body);
  res.status(201).json({ data: entry });
});

const getQueue = asyncHandler(async (req, res) => {
  res.json({ data: await service.getQueue(req.user.companyId) });
});

const callNextPatient = asyncHandler(async (req, res) => {
  const called = await service.callNextPatient(req.user.companyId);
  res.json({ data: called });
});

const completeConsultation = asyncHandler(async (req, res) => {
  const visit = await service.completeConsultation(req.user.companyId, req.params.id, req.body);
  res.json({ data: visit });
});

const cancelQueueEntry = asyncHandler(async (req, res) => {
  const cancelled = await service.cancelQueueEntry(req.user.companyId, req.params.id);
  res.json({ data: cancelled });
});

const addDocument = asyncHandler(async (req, res) => {
  const doc = await service.addDocument(req.user.companyId, req.user.id, req.body);
  res.status(201).json({ data: doc });
});

const deleteDocument = asyncHandler(async (req, res) => {
  const doc = await service.deleteDocument(req.user.companyId, req.params.id);
  res.json({ data: doc });
});

const createPrescription = asyncHandler(async (req, res) => {
  const prescription = await service.createPrescription(req.user.companyId, req.user.id, req.body);
  res.status(201).json({ data: prescription });
});

const getPrescription = asyncHandler(async (req, res) => {
  const prescription = await service.getPrescription(req.user.companyId, req.params.id);
  res.json({ data: prescription });
});

/** Ch. 4 "preview / download"  -  streams the file itself; ownership
 * already verified inside service.getDocumentFile (company-scoped
 * lookup), so nothing here trusts req.params.id beyond that check. */
const downloadDocument = asyncHandler(async (req, res) => {
  const file = await service.getDocumentFile(req.user.companyId, req.params.id);
  const disposition = req.query.download === '1' ? 'attachment' : 'inline';
  const safeName = String(file.fileName || 'document')
    .replace(/[\r\n"\\]/g, '_')
    .slice(0, 180);
  res.setHeader('Content-Type', file.mimeType);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', `${disposition}; filename="${safeName}"`);
  fs.createReadStream(file.absolutePath).pipe(res);
});

const getPrescriptionPdf = asyncHandler(async (req, res) => {
  await service.streamPrescriptionPdf(res, req.user.companyId, req.params.id);
});

const getVisitInvoice = asyncHandler(async (req, res) => {
  const invoice = await service.getVisitInvoice(req.user.companyId, req.params.id);
  res.json({ data: invoice });
});

const getVisitInvoicePdf = asyncHandler(async (req, res) => {
  await service.streamVisitInvoicePdf(res, req.user.companyId, req.params.id);
});

const getDashboard = asyncHandler(async (req, res) => {
  res.json({ data: await service.getDashboard(req.user.companyId) });
});

const recordPayment = asyncHandler(async (req, res) => {
  const result = await service.recordPayment(req.user.companyId, req.params.id, req.body);
  res.status(201).json({ data: result });
});

const refundVisit = asyncHandler(async (req, res) => {
  const result = await service.refundVisit(req.user.companyId, req.params.id, req.body?.note);
  res.json({ data: result });
});

module.exports = {
  createPatient,
  listPatients,
  getPatientProfile,
  updatePatient,
  deletePatient,
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
  downloadDocument,
  createPrescription,
  getPrescription,
  getPrescriptionPdf,
  getVisitInvoice,
  getVisitInvoicePdf,
  getDashboard,
};

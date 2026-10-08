const express = require('express');
const controller = require('./clinic.controller');
const {
  validateCreatePatient,
  validateCreateAppointment,
  validateAddToQueue,
  validateRecordPayment,
  validateCreatePrescription,
  validateAddDocument,
} = require('./clinic.validators');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const { requireBusinessType } = require('../../middlewares/businessType.middleware');

const router = express.Router();

router.use(authMiddleware);
// Dashboard-family simplification: 'dental_clinic' is a legacy/
// compatibility business_type value now folded into the Clinic family
// (mobile picker only offers 'clinic' to new signups  -  see
// business_type_screen.dart's kSelectableBusinessTypes and
// backend/SPECIALIZED_MODULES.md).
router.use(requireBusinessType('clinic', 'dental_clinic'));

router.get('/dashboard', controller.getDashboard);

router.post('/patients', validateCreatePatient, controller.createPatient);
router.get('/patients', controller.listPatients);
router.get('/patients/:id', controller.getPatientProfile);
router.put('/patients/:id', controller.updatePatient);
router.patch('/patients/:id', controller.updatePatient);
router.delete('/patients/:id', controller.deletePatient);

router.post('/appointments', validateCreateAppointment, controller.createAppointment);
router.get('/appointments', controller.listAppointments);
router.patch('/appointments/:id/status', controller.updateAppointmentStatus);

router.post('/queue', validateAddToQueue, controller.addToQueue);
router.get('/queue', controller.getQueue);
router.post('/queue/call-next', controller.callNextPatient);
router.post('/queue/:id/complete', controller.completeConsultation);
router.post('/queue/:id/cancel', controller.cancelQueueEntry);

router.post('/visits/:id/payments', validateRecordPayment, controller.recordPayment);
router.post('/visits/:id/refund', controller.refundVisit);
router.get('/visits/:id/invoice', controller.getVisitInvoice);
router.get('/visits/:id/invoice/pdf', controller.getVisitInvoicePdf);

router.post('/documents', validateAddDocument, controller.addDocument);
router.delete('/documents/:id', controller.deleteDocument);
router.get('/documents/:id/file', controller.downloadDocument);

router.post('/prescriptions', validateCreatePrescription, controller.createPrescription);
router.get('/prescriptions/:id', controller.getPrescription);
router.get('/prescriptions/:id/pdf', controller.getPrescriptionPdf);

module.exports = router;

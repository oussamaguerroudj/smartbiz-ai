const express = require('express');
const controller = require('./ai.controller');
const { validateScanInvoice, validateChat, validateFeedback } = require('./ai.validators');
const { authMiddleware, requireRole } = require('../../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/health', controller.health);
router.get('/config', controller.getConfig);
router.put('/config', requireRole('owner'), controller.updateConfig);

router.post('/invoices/scan', validateScanInvoice, controller.scanInvoice);
router.post('/ocr', validateScanInvoice, controller.extractOcr);
router.post('/invoices/scan/:id/confirm', controller.confirmScan);
router.post('/chat', validateChat, controller.chat);
router.get('/insights', controller.insights);
router.post('/logs/:id/feedback', validateFeedback, controller.submitFeedback);

module.exports = router;

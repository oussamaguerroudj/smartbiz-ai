const express = require('express');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const subscriptionsController = require('./subscriptions.controller');

const router = express.Router();

// Product info is available without authentication (for pre-login welcome/pricing display)
router.get('/product', subscriptionsController.getProduct);

// Scheduled Cron Trigger Endpoint (authenticated via high-entropy secret, rate-limited)
router.post('/cron/process-reminders', subscriptionsController.cronProcessReminders);

// Entitlement status and trial selection are strictly authenticated via JWT
router.use(authMiddleware);
router.get('/status', subscriptionsController.getStatus);
router.post('/trial', subscriptionsController.startTrial);

module.exports = router;

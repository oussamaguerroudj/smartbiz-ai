const express = require('express');
const { authMiddleware, requireRole } = require('../../middlewares/auth.middleware');
const { loginIpLimiter } = require('../../middlewares/rateLimit.middleware');
const adminController = require('./admin.controller');

const router = express.Router();

// 1. Dedicated Admin Login (rate limited)
router.post('/auth/login', loginIpLimiter, adminController.login);

// 2. Admin & Support Authenticated Endpoints
router.use(authMiddleware);
router.use(requireRole('super_admin', 'support'));

router.get('/overview', adminController.getOverview);
router.get('/users', adminController.listUsers);
router.get('/support', adminController.listSupport);
router.put('/support/:id/status', adminController.updateSupport);
router.get('/feedback', adminController.listFeedback);
router.put('/feedback/:id/status', adminController.updateFeedback);
router.get('/payments/manual', adminController.listManualPayments);

// 3. Super Admin Only Operations (sensitive license grant, suspension, manual payment approval)
router.post('/users/:id/grant-lifetime', requireRole('super_admin'), adminController.grantLifetime);
router.post('/users/:id/grant-temporary', requireRole('super_admin'), adminController.grantTemporary);
router.post('/users/:id/extend', requireRole('super_admin'), adminController.extendLicense);
router.post('/users/:id/suspend', requireRole('super_admin'), adminController.setSuspension);
router.post('/users/:id/approval', requireRole('super_admin'), adminController.reviewApproval);
router.post('/payments/manual/:id/decide', requireRole('super_admin'), adminController.decideManualPayment);
router.get('/audit-logs', requireRole('super_admin'), adminController.listAuditLogs);

module.exports = router;

const express = require('express');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const paymentsController = require('./payments.controller');

const router = express.Router();

// 1. Webhook endpoint (unauthenticated by JWT, cryptographically verified by HMAC-SHA256 signature)
router.post('/webhook/chargily', paymentsController.webhookChargily);

// 2. Authenticated payment endpoints
router.use(authMiddleware);

router.post('/checkout', paymentsController.checkout);
router.post('/manual-request', paymentsController.createManualRequest);
router.post('/manual-request/:id/receipt', paymentsController.uploadReceipt);
router.get('/manual-requests', paymentsController.listManualRequests);
router.get('/receipts/:filename', paymentsController.viewReceipt);
router.get('/orders/:orderId', paymentsController.getOrderStatus);
router.get('/active-order', paymentsController.getActiveOrder);

module.exports = router;

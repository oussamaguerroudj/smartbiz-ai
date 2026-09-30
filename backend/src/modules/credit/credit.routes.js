const express = require('express');
const controller = require('./credit.controller');
const { validateCreatePurchase, validateRecordPayment } = require('./credit.validators');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware);

router.post('/purchases', validateCreatePurchase, controller.createPurchase);
router.get('/purchases', controller.listPurchases);
router.get('/purchases/:id', controller.getPurchase);
router.post('/payments', validateRecordPayment, controller.recordPayment);
router.get('/customers/:customerId/transactions', controller.customerTransactions);
router.get('/summary', controller.summary);

module.exports = router;

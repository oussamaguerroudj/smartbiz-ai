const express = require('express');
const controller = require('./invoices.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', controller.list);
router.get('/:id', controller.getOne);
router.get('/:id/pdf', controller.pdfPlaceholder);
router.put('/:id/mark-paid', controller.markPaid);

module.exports = router;

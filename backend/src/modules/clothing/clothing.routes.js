const express = require('express');
const controller = require('./clothing.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const { requireBusinessType } = require('../../middlewares/businessType.middleware');

/**
 * Deliberately thin, same rationale as pharmacy.routes.js/
 * superette.routes.js: Products (now with size/color/brand, migration
 * 020), Sales, Suppliers and Customers are all CORE screens/endpoints
 * a clothing-store account already has full access to — this router
 * only adds the dashboard aggregate.
 */
const router = express.Router();

router.use(authMiddleware);
router.use(requireBusinessType('clothing'));

router.get('/dashboard', controller.getDashboard);

module.exports = router;

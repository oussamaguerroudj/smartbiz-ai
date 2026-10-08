const express = require('express');
const controller = require('./superette.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const { requireBusinessType } = require('../../middlewares/businessType.middleware');

/**
 * Deliberately thin, same rationale as pharmacy.routes.js: Products,
 * Sales, Purchases(-as-cost-tracking), Suppliers and Customers are all
 * CORE screens/endpoints a supérette account already has full access
 * to (`/products`, `/sales`, `/suppliers`, `/customers`, `/credit`)  - 
 * this router only adds the one thing that doesn't exist anywhere
 * else yet: the dashboard aggregate.
 */
const router = express.Router();

router.use(authMiddleware);
// Ch. 21 security audit: gated to the three business_type values
// main_shell.dart actually routes to SuperetteMainDashboardScreen
// (grocery/supermarket/retail_store)  -  matching the guard already
// added to /clinic/* and /restaurant/*. CORE routes this module
// depends on (/products, /sales, ...) intentionally stay ungated,
// since every business type is meant to use them.
router.use(requireBusinessType('grocery', 'supermarket', 'retail_store'));

router.get('/dashboard', controller.getDashboard);

module.exports = router;

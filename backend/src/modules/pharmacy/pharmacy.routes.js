const express = require('express');
const controller = require('./pharmacy.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const { requireBusinessType } = require('../../middlewares/businessType.middleware');

/**
 * Deliberately thin: Products, Sales, Purchases(-as-cost-tracking) and
 * Suppliers are all CORE screens/endpoints a pharmacy account already
 * has full access to (`/products`, `/sales`, `/suppliers`)  -  Ch. 21's
 * "reuse existing APIs" rule means this router only adds the two
 * things that don't exist anywhere else yet: the dashboard aggregate
 * and the expiring-products list.
 */
const router = express.Router();

router.use(authMiddleware);
router.use(requireBusinessType('pharmacy'));

router.get('/dashboard', controller.getDashboard);
router.get('/expiring-products', controller.getExpiringProducts);

module.exports = router;

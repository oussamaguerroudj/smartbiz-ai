const express = require('express');
const authRoutes = require('../modules/auth/auth.routes');
const productsRoutes = require('../modules/products/products.routes');
const salesRoutes = require('../modules/sales/sales.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/products', productsRoutes);
router.use('/sales', salesRoutes);

// Remaining modules (invoices, expenses, employees, appointments,
// customers, suppliers, reports, notifications, ai, dashboard) follow
// the exact same 4-file pattern (routes/controller/service/repository)
// and land in the next backend batch, mirroring the mobile app's
// features one-to-one now that the pattern is established and proven
// with the hardest case (Sales' transactional logic) already done.

module.exports = router;

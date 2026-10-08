const express = require('express');
const authRoutes = require('../modules/auth/auth.routes');
const companiesRoutes = require('../modules/companies/companies.routes');
const productsRoutes = require('../modules/products/products.routes');
const salesRoutes = require('../modules/sales/sales.routes');
const invoicesRoutes = require('../modules/invoices/invoices.routes');
const expensesRoutes = require('../modules/expenses/expenses.routes');
const employeesRoutes = require('../modules/employees/employees.routes');
const appointmentsRoutes = require('../modules/appointments/appointments.routes');
const customersRoutes = require('../modules/customers/customers.routes');
const suppliersRoutes = require('../modules/suppliers/suppliers.routes');
const reportsRoutes = require('../modules/reports/reports.routes');
const notificationsRoutes = require('../modules/notifications/notifications.routes');
const dashboardRoutes = require('../modules/dashboard/dashboard.routes');
const aiRoutes = require('../modules/ai/ai.routes');
const creditRoutes = require('../modules/credit/credit.routes');
const syncRoutes = require('../modules/sync/sync.routes');
const imagesRoutes = require('../modules/images/images.routes');
const clinicRoutes = require('../modules/clinic/clinic.routes');
const restaurantRoutes = require('../modules/restaurant/restaurant.routes');
const pharmacyRoutes = require('../modules/pharmacy/pharmacy.routes');
const superetteRoutes = require('../modules/superette/superette.routes');
const clothingRoutes = require('../modules/clothing/clothing.routes');
const enterpriseRoutes = require('../modules/enterprise/enterprise.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/companies', companiesRoutes);
router.use('/products', productsRoutes);
router.use('/sales', salesRoutes);
router.use('/invoices', invoicesRoutes);
router.use('/expenses', expensesRoutes);
router.use('/employees', employeesRoutes);
router.use('/appointments', appointmentsRoutes);
router.use('/customers', customersRoutes);
router.use('/suppliers', suppliersRoutes);
router.use('/reports', reportsRoutes);
router.use('/notifications', notificationsRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/ai', aiRoutes);
router.use('/credit', creditRoutes);
router.use('/sync', syncRoutes);
// Ch. 17/18 — shared image upload/serve, reused by products,
// restaurant menu items, and restaurant inventory (see
// images.routes.js's header comment); not tied to any one
// business_type, so it is mounted here alongside the other CORE routes
// rather than under a single specialized prefix.
router.use('/images', imagesRoutes);
// Ch. 2 SPECIALIZED modules — each mounted under its own prefix, only
// ever relevant to companies whose business_type matches; CORE routes
// above are completely unaffected by this or any future specialized
// module (restaurant, gym, hotel, ...) being added the same way.
router.use('/clinic', clinicRoutes);
router.use('/restaurant', restaurantRoutes);
router.use('/pharmacy', pharmacyRoutes);
router.use('/superette', superetteRoutes);
router.use('/clothing', clothingRoutes);
router.use('/enterprise', enterpriseRoutes);

// Phase 6 ("OpenAI + OCR + AI Assistant + AI Insights + Invoice
// Scanner") is now wired up above: POST /ai/invoices/scan,
// POST /ai/invoices/scan/:id/confirm, POST /ai/chat, GET /ai/insights.
// Requires OPENAI_API_KEY to be set in .env — without it, these
// endpoints respond 503 AI_NOT_CONFIGURED rather than crashing the
// rest of the API.

module.exports = router;


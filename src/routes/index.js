const express = require('express');
const authRoutes = require('../modules/auth/auth.routes');
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

const router = express.Router();

router.use('/auth', authRoutes);
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

// Remaining: AI proxy endpoints (/ai/invoices/scan, /ai/chat, /ai/insights)
// — these need the OpenAI API key + OCR pipeline, which is explicitly
// Phase 6 ("OpenAI + OCR + AI Assistant + AI Insights + Invoice
// Scanner"). Every other module from the Phase 1 API architecture
// overview is now implemented.

module.exports = router;


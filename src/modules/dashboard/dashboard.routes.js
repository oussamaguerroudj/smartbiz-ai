const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const { authMiddleware } = require('../../middlewares/auth.middleware');

/**
 * Dashboard — Spec Ch. 9.1. Every KPI here matches the exact formula
 * table in the spec (Today's Revenue, Today's Expenses, Today's Profit,
 * Number of Sales, Low Stock Products, Unpaid Invoices, Upcoming
 * Appointments) — all live SQL aggregates, single round trip via
 * Promise.all for latency (spec requires the dashboard to answer
 * "how is my business doing" within ~2 seconds).
 */
const getDashboard = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;

  const [todaySales, todayExpenses, salesCount, lowStock, unpaidInvoices, upcomingAppointments] =
    await Promise.all([
      query(
        `SELECT COALESCE(SUM(total), 0) AS revenue, COALESCE(SUM(si.line_profit), 0) AS profit
         FROM sales s LEFT JOIN sale_items si ON si.sale_id = s.id
         WHERE s.company_id = $1 AND s.sold_at::date = CURRENT_DATE`,
        [companyId],
      ),
      query(
        `SELECT COALESCE(SUM(amount), 0) AS total FROM expenses
         WHERE company_id = $1 AND deleted_at IS NULL AND expense_date = CURRENT_DATE`,
        [companyId],
      ),
      query(
        `SELECT COUNT(*)::int AS count FROM sales WHERE company_id = $1 AND sold_at::date = CURRENT_DATE`,
        [companyId],
      ),
      query(
        `SELECT COUNT(*)::int AS count FROM products
         WHERE company_id = $1 AND deleted_at IS NULL AND quantity <= minimum_stock`,
        [companyId],
      ),
      query(
        `SELECT COUNT(*)::int AS count FROM invoices WHERE company_id = $1 AND status = 'unpaid'`,
        [companyId],
      ),
      query(
        `SELECT COUNT(*)::int AS count FROM appointments
         WHERE company_id = $1 AND status = 'scheduled' AND scheduled_at >= now()`,
        [companyId],
      ),
    ]);

  const revenue = Number(todaySales.rows[0].revenue);
  const expenses = Number(todayExpenses.rows[0].total);

  res.json({
    data: {
      todayRevenue: revenue,
      todayExpenses: expenses,
      todayProfit: revenue - expenses,
      salesCount: salesCount.rows[0].count,
      lowStockCount: lowStock.rows[0].count,
      unpaidInvoicesCount: unpaidInvoices.rows[0].count,
      upcomingAppointmentsCount: upcomingAppointments.rows[0].count,
    },
  });
});

const router = express.Router();
router.use(authMiddleware);
router.get('/', getDashboard);

module.exports = router;

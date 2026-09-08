const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const { authMiddleware } = require('../../middlewares/auth.middleware');

/**
 * Dashboard — all KPIs are calculated server-side from real database data.
 */
const getDashboard = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;

  const [
    todaySales,
    todayExpenses,
    salesCount,
    lowStock,
    unpaidInvoices,
    upcomingAppointments,
  ] = await Promise.all([
    // Aggregate sales separately from sale_items so revenue is not
    // multiplied by the number of items in a sale.
    query(
      `SELECT
         COALESCE(SUM(s.total), 0) AS revenue
       FROM sales s
       WHERE s.company_id = $1
         AND s.sold_at::date = CURRENT_DATE`,
      [companyId],
    ),

    query(
      `SELECT COALESCE(SUM(amount), 0) AS total
       FROM expenses
       WHERE company_id = $1
         AND deleted_at IS NULL
         AND expense_date = CURRENT_DATE`,
      [companyId],
    ),

    query(
      `SELECT COUNT(*)::int AS count
       FROM sales
       WHERE company_id = $1
         AND sold_at::date = CURRENT_DATE`,
      [companyId],
    ),

    query(
      `SELECT COUNT(*)::int AS count
       FROM products
       WHERE company_id = $1
         AND deleted_at IS NULL
         AND quantity <= minimum_stock`,
      [companyId],
    ),

    query(
      `SELECT COUNT(*)::int AS count
       FROM invoices
       WHERE company_id = $1
         AND status = 'unpaid'`,
      [companyId],
    ),

    query(
      `SELECT COUNT(*)::int AS count
       FROM appointments
       WHERE company_id = $1
         AND status = 'scheduled'
         AND scheduled_at >= now()`,
      [companyId],
    ),
  ]);

  const revenue = Number(todaySales.rows[0].revenue);
  const expenses = Number(todayExpenses.rows[0].total);

  return res.json({
    data: {
      todayRevenue: revenue,
      todayExpenses: expenses,
      todayProfit: revenue - expenses,
      salesCount: salesCount.rows[0].count,
      lowStockCount: lowStock.rows[0].count,
      unpaidInvoicesCount: unpaidInvoices.rows[0].count,
      upcomingAppointmentsCount:
        upcomingAppointments.rows[0].count,
    },
  });
});

const router = express.Router();

router.use(authMiddleware);

router.get('/', getDashboard);

module.exports = router;
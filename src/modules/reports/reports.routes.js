const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const PERIOD_INTERVALS = {
  daily: "date_trunc('day', now())",
  weekly: "now() - interval '7 days'",
  monthly: "date_trunc('month', now())",
  yearly: "date_trunc('year', now())",
};

/**
 * Reports — Spec Ch. 22. Every figure is a real SQL aggregate over
 * `sales`/`expenses` for the requesting company — no client-side
 * recomputation, no invented numbers. PDF/Excel export (Ch. 22) needs
 * dedicated libraries (pdfkit / exceljs) and is deferred to its own
 * batch, same reasoning as Invoices PDF export.
 */
const getReport = asyncHandler(async (req, res) => {
  const period = req.query.period || 'monthly';
  const cutoffExpr = PERIOD_INTERVALS[period];
  if (!cutoffExpr) {
    throw ApiError.badRequest('period must be daily, weekly, monthly, or yearly', 'VALIDATION_ERROR');
  }

  const companyId = req.user.companyId;

  const salesResult = await query(
    `SELECT COALESCE(SUM(s.total), 0) AS revenue,
            COALESCE(SUM(si.line_profit), 0) AS gross_profit,
            COUNT(DISTINCT s.id)::int AS sales_count
     FROM sales s
     LEFT JOIN sale_items si ON si.sale_id = s.id
     WHERE s.company_id = $1 AND s.sold_at >= ${cutoffExpr}`,
    [companyId],
  );

  const expensesResult = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total FROM expenses
     WHERE company_id = $1 AND deleted_at IS NULL AND expense_date >= ${cutoffExpr}`,
    [companyId],
  );

  const topProductsResult = await query(
    `SELECT p.name, SUM(si.quantity)::int AS units_sold
     FROM sale_items si
     JOIN sales s ON s.id = si.sale_id
     JOIN products p ON p.id = si.product_id
     WHERE s.company_id = $1 AND s.sold_at >= ${cutoffExpr}
     GROUP BY p.name
     ORDER BY units_sold DESC
     LIMIT 5`,
    [companyId],
  );

  const revenue = Number(salesResult.rows[0].revenue);
  const expenseTotal = Number(expensesResult.rows[0].total);

  res.json({
    data: {
      period,
      revenue,
      expenses: expenseTotal,
      netProfit: revenue - expenseTotal,
      grossProfit: Number(salesResult.rows[0].gross_profit),
      salesCount: salesResult.rows[0].sales_count,
      topProducts: topProductsResult.rows,
    },
  });
});

const router = express.Router();
router.use(authMiddleware);
router.get('/', getReport);

module.exports = router;

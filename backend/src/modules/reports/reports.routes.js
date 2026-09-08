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
 * Reports — all figures are calculated server-side from database aggregates.
 * `cutoffExpr` is selected only from the fixed whitelist above, never from
 * raw client input, so it is safe to interpolate into the SQL statements.
 */
const getReport = asyncHandler(async (req, res) => {
  const period = req.query.period || 'monthly';
  const cutoffExpr = PERIOD_INTERVALS[period];

  if (!cutoffExpr) {
    throw ApiError.badRequest(
      'period must be daily, weekly, monthly, or yearly',
      'VALIDATION_ERROR',
    );
  }

  const companyId = req.user.companyId;

  // Aggregate sales separately from sale_items so sale.total is never
  // multiplied by the number of items in the sale.
  const salesResult = await query(
    `SELECT
       COALESCE(SUM(s.total), 0) AS revenue,
       COALESCE(
         (
           SELECT SUM(si.line_profit)
           FROM sale_items si
           JOIN sales s2
             ON s2.id = si.sale_id
            AND s2.company_id = s.company_id
           WHERE s2.company_id = $1
             AND s2.sold_at >= ${cutoffExpr}
         ),
         0
       ) AS gross_profit,
       COUNT(*)::int AS sales_count
     FROM sales s
     WHERE s.company_id = $1
       AND s.sold_at >= ${cutoffExpr}`,
    [companyId],
  );

  const expensesResult = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total
     FROM expenses
     WHERE company_id = $1
       AND deleted_at IS NULL
       AND expense_date >= ${cutoffExpr}`,
    [companyId],
  );

  const topProductsResult = await query(
    `SELECT
       p.name,
       SUM(si.quantity)::int AS units_sold
     FROM sale_items si
     JOIN sales s
       ON s.id = si.sale_id
      AND s.company_id = $1
     JOIN products p
       ON p.id = si.product_id
      AND p.company_id = s.company_id
     WHERE s.company_id = $1
       AND s.sold_at >= ${cutoffExpr}
     GROUP BY p.id, p.name
     ORDER BY units_sold DESC
     LIMIT 5`,
    [companyId],
  );

  const revenue = Number(salesResult.rows[0].revenue);
  const expenseTotal = Number(expensesResult.rows[0].total);
  const grossProfit = Number(salesResult.rows[0].gross_profit);

  return res.json({
    data: {
      period,
      revenue,
      expenses: expenseTotal,
      netProfit: revenue - expenseTotal,
      grossProfit,
      salesCount: salesResult.rows[0].sales_count,
      topProducts: topProductsResult.rows,
    },
  });
});

const router = express.Router();

router.use(authMiddleware);

router.get('/', getReport);

module.exports = router;
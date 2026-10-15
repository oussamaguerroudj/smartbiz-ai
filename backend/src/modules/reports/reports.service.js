const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

/**
 * Returns slow-moving products for the given company based on actual sales records.
 *
 * CRITICAL BUSINESS RULE:
 * Products created more recently than the observation window (e.g. added 5 days ago in a 30-day window)
 * do NOT have sufficient historical sales data. They are excluded by default to avoid false positives,
 * or flagged with `insufficient_history: true` when explicitly requested.
 */
async function getSlowMovingProducts(companyId, options = {}) {
  if (!companyId) {
    throw ApiError.unauthorized('Company identification required');
  }

  const rawDays = options.days !== undefined ? Number(options.days) : 30;
  if (isNaN(rawDays) || rawDays < 1 || rawDays > 365) {
    throw ApiError.badRequest('days must be an integer between 1 and 365', 'VALIDATION_ERROR');
  }
  const days = Math.floor(rawDays);

  const rawThreshold = options.threshold !== undefined ? Number(options.threshold) : 2;
  if (isNaN(rawThreshold) || rawThreshold < 0 || rawThreshold > 10000) {
    throw ApiError.badRequest('threshold must be a non-negative integer', 'VALIDATION_ERROR');
  }
  const threshold = Math.floor(rawThreshold);

  const category = options.category ? String(options.category).trim() : null;
  const includeInsufficient = options.includeInsufficient === true || options.includeInsufficient === 'true' || options.include_insufficient === 'true';

  const sql = `
    SELECT
      p.id,
      p.name,
      p.category,
      p.barcode,
      p.quantity AS current_stock,
      p.purchase_price::numeric(12,2) AS purchase_price,
      p.selling_price::numeric(12,2) AS selling_price,
      p.created_at,
      COALESCE(sales_agg.units_sold, 0)::int AS units_sold,
      CASE
        WHEN p.created_at > now() - ($2 || ' days')::interval THEN true
        ELSE false
      END AS insufficient_history,
      ROUND(EXTRACT(EPOCH FROM (now() - p.created_at)) / 86400)::int AS days_in_inventory
    FROM products p
    LEFT JOIN (
      SELECT product_id, SUM(quantity)::int AS units_sold FROM (
        SELECT si.product_id, si.quantity
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        WHERE s.company_id = $1 AND s.sold_at >= now() - ($2 || ' days')::interval
        UNION ALL
        SELECT cpi.product_id, cpi.quantity
        FROM credit_purchase_items cpi
        JOIN credit_purchases cp ON cp.id = cpi.credit_purchase_id
        WHERE cp.company_id = $1 AND cp.created_at >= now() - ($2 || ' days')::interval
      ) all_sales
      GROUP BY product_id
    ) sales_agg ON sales_agg.product_id = p.id
    WHERE p.company_id = $1
      AND p.deleted_at IS NULL
      AND ($4::boolean = true OR p.created_at <= now() - ($2 || ' days')::interval)
      AND COALESCE(sales_agg.units_sold, 0) <= $3
      AND ($5::text IS NULL OR p.category = $5)
    ORDER BY units_sold ASC, current_stock DESC, p.name ASC
  `;

  const result = await query(sql, [
    companyId,
    days,
    threshold,
    includeInsufficient,
    category,
  ]);

  const items = result.rows.map((row) => ({
    id: row.id,
    name: row.name,
    category: row.category,
    barcode: row.barcode,
    currentStock: Number(row.current_stock),
    purchasePrice: parseFloat(row.purchase_price) || 0,
    sellingPrice: parseFloat(row.selling_price) || 0,
    unitsSold: Number(row.units_sold),
    insufficientHistory: row.insufficient_history === true,
    daysInInventory: Number(row.days_in_inventory),
    createdAt: row.created_at,
    stockValuation: Math.round((Number(row.current_stock) * (parseFloat(row.purchase_price) || 0)) * 100) / 100,
  }));

  return {
    periodDays: days,
    threshold,
    categoryFilter: category,
    totalCount: items.length,
    generatedAt: new Date().toISOString(),
    items,
  };
}

module.exports = {
  getSlowMovingProducts,
};

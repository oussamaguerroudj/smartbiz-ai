const { query } = require('../../config/db');

/**
 * Pharmacy vertical (business-specialization brief Ch. 15). Unlike
 * Clinic/Restaurant, Pharmacy needs NO new tables and NO migration —
 * per Ch. 21's "reuse existing backend/database/business logic
 * whenever possible", this module is a thin, read-mostly aggregation
 * layer over the CORE `products`/`sales`/`sale_items` tables that
 * already exist for every business type. `products.expiration_date`
 * (migration 006) was already reserved for exactly this use case and
 * was simply unused by any screen until now.
 *
 * Every query still takes companyId as its first bound parameter,
 * same tenant-isolation rule as every other module.
 */

async function expiringProducts(companyId, days = 30, limit = 30) {
  const result = await query(
    `SELECT id, name, category, quantity, expiration_date
     FROM products
     WHERE company_id = $1
       AND deleted_at IS NULL
       AND expiration_date IS NOT NULL
       AND expiration_date <= (CURRENT_DATE + ($2 || ' days')::interval)
     ORDER BY expiration_date ASC
     LIMIT $3`,
    [companyId, days, limit],
  );
  return result.rows;
}

async function expiringCount(companyId, days = 30) {
  const result = await query(
    `SELECT COUNT(*)::int AS count
     FROM products
     WHERE company_id = $1
       AND deleted_at IS NULL
       AND expiration_date IS NOT NULL
       AND expiration_date <= (CURRENT_DATE + ($2 || ' days')::interval)`,
    [companyId, days],
  );
  return result.rows[0].count;
}

/** Already-expired stock — distinct from "expiring soon" (Ch. 15's
 * "Expiring products" alert), since an already-expired item needs to
 * be pulled from sale, not just reordered. */
async function expiredCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count
     FROM products
     WHERE company_id = $1 AND deleted_at IS NULL
       AND expiration_date IS NOT NULL AND expiration_date < CURRENT_DATE`,
    [companyId],
  );
  return result.rows[0].count;
}

async function lowStockProducts(companyId, limit = 30) {
  const result = await query(
    `SELECT id, name, category, quantity, minimum_stock
     FROM products
     WHERE company_id = $1 AND deleted_at IS NULL AND quantity <= minimum_stock
     ORDER BY quantity ASC
     LIMIT $2`,
    [companyId, limit],
  );
  return result.rows;
}

async function lowStockCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM products
     WHERE company_id = $1 AND deleted_at IS NULL AND quantity <= minimum_stock`,
    [companyId],
  );
  return result.rows[0].count;
}

/** Inventory value at cost (what's tied up in stock) and at retail
 * (what it would sell for) — Ch. 15's "Inventory value". No purchases
 * ledger exists anywhere in this codebase (see ai.tools.js's
 * `get_suppliers` comment for the same documented gap), so "Purchase
 * costs" as a distinct today/this-week figure is intentionally NOT
 * fabricated here — only this real, queryable snapshot is exposed. */
async function inventoryValue(companyId) {
  const result = await query(
    `SELECT
       COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * COALESCE(NULLIF(purchase_price, 0), selling_price, 0) ELSE 0 END), 0) AS cost_value,
       COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * COALESCE(selling_price, 0) ELSE 0 END), 0) AS retail_value,
       COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity ELSE 0 END), 0)::int AS units_in_stock
     FROM products
     WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return {
    costValue: Number(result.rows[0].cost_value),
    retailValue: Number(result.rows[0].retail_value),
    unitsInStock: result.rows[0].units_in_stock,
  };
}

/** Today's sales, revenue and cost-of-goods-aware gross profit —
 * same shape/formula as the CORE dashboard's own today-sales query
 * (dashboard.routes.js) and Reports' `grossProfit` (reports.routes.js),
 * reused rather than reinvented. */
async function salesSummaryForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT
       COALESCE(SUM(s.total), 0) AS revenue,
       COALESCE((
         SELECT SUM(si.line_profit) FROM sale_items si
         JOIN sales s2 ON s2.id = si.sale_id
         WHERE s2.company_id = $1 AND s2.sold_at::date BETWEEN $2::date AND $3::date
       ), 0) AS gross_profit,
       COUNT(*)::int AS transaction_count,
       COALESCE((
         SELECT SUM(si.quantity) FROM sale_items si
         JOIN sales s2 ON s2.id = si.sale_id
         WHERE s2.company_id = $1 AND s2.sold_at::date BETWEEN $2::date AND $3::date
       ), 0)::int AS units_sold
     FROM sales s
     WHERE s.company_id = $1 AND s.sold_at::date BETWEEN $2::date AND $3::date`,
    [companyId, rangeStart, rangeEnd],
  );
  const row = result.rows[0];
  return {
    revenue: Number(row.revenue),
    grossProfit: Number(row.gross_profit),
    transactionCount: row.transaction_count,
    unitsSold: row.units_sold,
  };
}

/** Best-selling products this week — same query shape as Reports'
 * `topProducts` (reports.routes.js), scoped here for the Pharmacy
 * dashboard's own "Products sold" snapshot. */
async function bestSellingProducts(companyId, rangeStart, rangeEnd, limit = 5) {
  const result = await query(
    `SELECT p.name, SUM(si.quantity)::int AS units_sold,
            COALESCE(SUM(si.line_total), 0) AS revenue
     FROM sale_items si
     JOIN sales s ON s.id = si.sale_id AND s.company_id = $1
     JOIN products p ON p.id = si.product_id AND p.company_id = s.company_id
     WHERE s.sold_at::date BETWEEN $2::date AND $3::date
     GROUP BY p.id, p.name
     ORDER BY units_sold DESC
     LIMIT $4`,
    [companyId, rangeStart, rangeEnd, limit],
  );
  return result.rows;
}

/** Supplier count — Ch. 15's "Supplier information". No dedicated
 * suppliers repository module exists to import from (its queries live
 * inline in suppliers.routes.js), so this is queried directly here,
 * same lightweight-count pattern as lowStockCount/expiringCount above. */
async function suppliersCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM suppliers WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return result.rows[0].count;
}

module.exports = {
  expiringProducts,
  expiringCount,
  expiredCount,
  lowStockProducts,
  lowStockCount,
  inventoryValue,
  salesSummaryForRange,
  bestSellingProducts,
  suppliersCount,
};

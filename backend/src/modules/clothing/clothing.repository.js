const { query } = require('../../config/db');

/**
 * Clothing Store vertical (business-specialization brief Ch. 18).
 * Fifth specialized vertical. Reuses `products`/`sales`/`sale_items`/
 * `suppliers`/`customers` exactly like Pharmacy (§11) and Supérette
 * (§12) — per Ch. 21, no `clothing_*` tables were created.
 *
 * Ch. 18 explicitly asks for Size/Color/Brand attributes, which did
 * NOT exist anywhere in the schema until migration
 * 020_add_clothing_attributes.sql added three plain nullable columns
 * to the existing CORE `products` table (see that migration's own
 * comment for why a column, not a new table, was the right call).
 *
 * Deliberately NOT built here: a Returns KPI/flow. There is no
 * returns/refunds table or column anywhere in this codebase — same
 * "don't fake data" call pharmacy.repository.js already documented
 * for its missing Purchase-costs figure. A `product_returns` table
 * (or a `sales.status = 'returned'` column) would be the natural next
 * migration if this is prioritized later.
 *
 * Every query still takes companyId as its first bound parameter,
 * same tenant-isolation rule as every other module.
 */

async function lowStockProducts(companyId, limit = 30) {
  const result = await query(
    `SELECT id, name, category, size, color, brand, quantity, minimum_stock
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

/** Stock value at cost and at retail — same shape as
 * pharmacy.repository.js's inventoryValue / superette.repository.js's
 * stockValue. */
async function stockValue(companyId) {
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

/** Today's/period sales, revenue and cost-of-goods-aware gross profit
 * — identical shape/formula to pharmacy/superette's salesSummaryForRange. */
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

/** Best-selling items this week — same query shape as
 * pharmacy/superette's bestSellingProducts, plus size/color/brand so
 * the Clothing dashboard can show "what's actually selling" at the
 * attribute level Ch. 18 asks for, not just by product name. */
async function bestSellingProducts(companyId, rangeStart, rangeEnd, limit = 5) {
  const result = await query(
    `SELECT p.name, p.size, p.color, p.brand,
            SUM(si.quantity)::int AS units_sold,
            COALESCE(SUM(si.line_total), 0) AS revenue
     FROM sale_items si
     JOIN sales s ON s.id = si.sale_id AND s.company_id = $1
     JOIN products p ON p.id = si.product_id AND p.company_id = s.company_id
     WHERE s.sold_at::date BETWEEN $2::date AND $3::date
     GROUP BY p.id, p.name, p.size, p.color, p.brand
     ORDER BY units_sold DESC
     LIMIT $4`,
    [companyId, rangeStart, rangeEnd, limit],
  );
  return result.rows;
}

/** Ch. 18's "Categories" — stock split by category (e.g. Men/Women/
 * Kids), reusing the same `category` column every other vertical
 * already uses, not a new clothing-only concept. */
async function stockByCategory(companyId, limit = 10) {
  const result = await query(
    `SELECT COALESCE(category, 'Uncategorized') AS category,
            COUNT(*)::int AS product_count,
            COALESCE(SUM(quantity), 0)::int AS units_in_stock
     FROM products
     WHERE company_id = $1 AND deleted_at IS NULL
     GROUP BY category
     ORDER BY units_in_stock DESC
     LIMIT $2`,
    [companyId, limit],
  );
  return result.rows;
}

async function suppliersCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM suppliers WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return result.rows[0].count;
}

/** Ch. 18's "Customers" + "Credit/customer debt" — same shape as
 * superette.repository.js's customerDebt. */
async function customerDebt(companyId, limit = 5) {
  const [totalResult, listResult] = await Promise.all([
    query(
      `SELECT COALESCE(SUM(balance_due), 0) AS total, COUNT(*)::int AS count
       FROM customers
       WHERE company_id = $1 AND deleted_at IS NULL AND balance_due > 0`,
      [companyId],
    ),
    query(
      `SELECT id, name, phone, balance_due
       FROM customers
       WHERE company_id = $1 AND deleted_at IS NULL AND balance_due > 0
       ORDER BY balance_due DESC
       LIMIT $2`,
      [companyId, limit],
    ),
  ]);
  return {
    totalOutstanding: Number(totalResult.rows[0].total),
    debtorsCount: totalResult.rows[0].count,
    topDebtors: listResult.rows,
  };
}

async function customersCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM customers WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return result.rows[0].count;
}

module.exports = {
  lowStockProducts,
  lowStockCount,
  stockValue,
  salesSummaryForRange,
  bestSellingProducts,
  stockByCategory,
  suppliersCount,
  customerDebt,
  customersCount,
};

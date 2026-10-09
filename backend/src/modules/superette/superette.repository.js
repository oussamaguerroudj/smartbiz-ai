const { query } = require('../../config/db');

/**
 * Supérette / General Store vertical (business-specialization brief
 * Ch. 16). Fourth specialized vertical, built by following §11's
 * Pharmacy pattern to the letter: `products`/`sales`/`sale_items`/
 * `suppliers`/`customers` already model everything Ch. 16 asks for
 * (Products, Stock, Sales, Purchases-as-cost-tracking, Suppliers,
 * Customers, Credit/customer debt) — per Ch. 21's "reuse existing
 * backend/database/business logic whenever possible", NO new tables
 * and NO migration were added for this vertical either.
 *
 * The one deliberate difference from Pharmacy: no expiry-alert
 * emphasis here (Ch. 16 doesn't list it the way Ch. 15 does for
 * Pharmacy) — instead this module surfaces customer credit/debt
 * (`customers.balance_due`), which Pharmacy's dashboard doesn't.
 * `expiringProducts`/`expiringCount` are intentionally NOT duplicated
 * here: `pharmacy.repository.js`'s versions are already
 * business-type-agnostic queries over `products.expiration_date` (see
 * that file's own doc comment), so a Supérette screen that wants an
 * expiry widget later can import them directly instead of a second
 * copy being created here.
 *
 * Every query still takes companyId as its first bound parameter,
 * same tenant-isolation rule as every other module.
 */

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

/** Stock value at cost and at retail — Ch. 16's "Stock value", same
 * shape as pharmacy.repository.js's inventoryValue. */
async function stockValue(companyId) {
  const result = await query(
    `SELECT
       COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * (COALESCE(selling_price, 0) - COALESCE(purchase_price, 0)) ELSE 0 END), 0) AS cost_value,
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
 * — identical shape/formula to pharmacy.repository.js's
 * salesSummaryForRange, reused rather than reinvented (Ch. 21). */
async function salesSummaryForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT
       COALESCE((
         SELECT SUM(s2.total)
         FROM sales s2
         WHERE s2.company_id = $1 AND s2.sold_at::date BETWEEN $2::date AND $3::date
       ), 0) AS revenue,
       COALESCE((
         SELECT SUM(s2.total)
         FROM sales s2
         WHERE s2.company_id = $1 AND s2.sold_at::date BETWEEN $2::date AND $3::date
       ), 0) - COALESCE((
         SELECT SUM(si.unit_cost * si.quantity)
         FROM sale_items si
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
  const row = result.rows[0] || { revenue: 0, gross_profit: 0, transaction_count: 0, units_sold: 0 };
  return {
    revenue: Number(row.revenue),
    grossProfit: Number(row.gross_profit),
    transactionCount: Number(row.transaction_count || 0),
    unitsSold: Number(row.units_sold || 0),
  };
}

/** Best-selling products this week — same query shape as Reports'
 * `topProducts` / pharmacy.repository.js's bestSellingProducts. */
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

async function suppliersCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM suppliers WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return result.rows[0].count;
}

/** Ch. 16's "Credit/customer debt when applicable" — total outstanding
 * balance across every customer, plus a short list of the biggest
 * debtors (same query `get_customers_with_debt` already uses in
 * ai.tools.js, kept in sync here rather than reinvented). */
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
  suppliersCount,
  customerDebt,
  customersCount,
};

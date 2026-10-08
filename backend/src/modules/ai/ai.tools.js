const { query } = require('../../config/db');
const expensesRepo = require('../expenses/expenses.repository');
const employeesRepo = require('../employees/employees.repository');
const creditRepo = require('../credit/credit.repository');
const clinicRepo = require('../clinic/clinic.repository');
const clinicService = require('../clinic/clinic.service');
const restaurantRepo = require('../restaurant/restaurant.repository');
const restaurantService = require('../restaurant/restaurant.service');
const pharmacyRepo = require('../pharmacy/pharmacy.repository');
const pharmacyService = require('../pharmacy/pharmacy.service');
const superetteService = require('../superette/superette.service');
const enterpriseService = require('../enterprise/enterprise.service');
const clothingService = require('../clothing/clothing.service');
const { expandSearchAliases } = require('./language.detector');

/**
 * Tool/function-calling architecture (Ch. 8).
 *
 * SECURITY (Ch. 29  -  this is the load-bearing guarantee of the whole
 * module): the LLM never sees a raw SQL connection or a company_id it
 * could tamper with. `executeTool` below ALWAYS takes companyId from
 * the authenticated request (ai.service.js passes it through, itself
 * taken from req.user.companyId in ai.controller.js)  -  never from the
 * model's tool-call arguments. Every query in this file has a
 * `WHERE company_id = $1` (or equivalent join) using that same
 * server-supplied value. A user asking "show me another company's
 * sales" cannot succeed: there is no argument path from the model's
 * output to which company_id gets queried.
 */

function resolvePeriodRange(period) {
  const now = new Date();
  const toDateStr = (d) => d.toISOString().slice(0, 10);

  switch (period) {
    case 'today':
      return { start: toDateStr(now), end: toDateStr(now) };
    case 'yesterday': {
      const d = new Date(now);
      d.setUTCDate(d.getUTCDate() - 1);
      return { start: toDateStr(d), end: toDateStr(d) };
    }
    case 'last_month': {
      const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
      const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 0));
      return { start: toDateStr(start), end: toDateStr(end) };
    }
    case 'this_year':
      return { start: `${now.getUTCFullYear()}-01-01`, end: toDateStr(now) };
    case 'this_month':
    default:
      return {
        start: toDateStr(new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))),
        end: toDateStr(now),
      };
  }
}

async function salesTotals(companyId, start, end) {
  const result = await query(
    `SELECT
       COALESCE((
         SELECT SUM(COALESCE(si.line_profit, (si.unit_price - si.unit_cost) * si.quantity))
         FROM sale_items si
         JOIN sales s2 ON s2.id = si.sale_id
         WHERE s2.company_id = $1 AND s2.sold_at::date BETWEEN $2::date AND $3::date
       ), 0) AS revenue,
       COUNT(*)::int AS order_count
     FROM sales
     WHERE company_id = $1 AND sold_at::date BETWEEN $2::date AND $3::date`,
    [companyId, start, end],
  );
  const revenue = Number(result.rows[0].revenue);
  const orderCount = result.rows[0].order_count;
  return {
    revenue,
    orderCount,
    averageOrderValue: orderCount > 0 ? Math.round((revenue / orderCount) * 100) / 100 : 0,
  };
}

// ---------------------------------------------------------------------
// Tool implementations  -  each takes (companyId, args)
// ---------------------------------------------------------------------

async function get_sales_summary(companyId, { period = 'this_month' } = {}) {
  const { start, end } = resolvePeriodRange(period);
  const totals = await salesTotals(companyId, start, end);
  return { period, rangeStart: start, rangeEnd: end, ...totals };
}

async function get_sales(companyId, { period = 'today', limit = 10 } = {}) {
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 10));
  const { start, end } = resolvePeriodRange(period);
  const res = await query(
    `SELECT s.id, s.total, s.payment_status, s.sold_at, c.name AS customer_name,
            COUNT(si.id)::int AS items_count
     FROM sales s
     LEFT JOIN customers c ON c.id = s.customer_id AND c.company_id = s.company_id
     LEFT JOIN sale_items si ON si.sale_id = s.id
     WHERE s.company_id = $1 AND s.sold_at::date BETWEEN $2::date AND $3::date
     GROUP BY s.id, c.name
     ORDER BY s.sold_at DESC
     LIMIT $4`,
    [companyId, start, end, safeLimit],
  );
  return {
    period,
    rangeStart: start,
    rangeEnd: end,
    count: res.rows.length,
    sales: res.rows.map((r) => ({
      id: r.id,
      total: Number(r.total),
      payment_status: r.payment_status,
      sold_at: r.sold_at,
      customer_name: r.customer_name,
      items_count: r.items_count,
    })),
  };
}

async function get_top_products(companyId, { period = 'this_month', limit = 5 } = {}) {
  const { start, end } = resolvePeriodRange(period);
  const safeLimit = Math.min(20, Math.max(1, Number(limit) || 5));

  const result = await query(
    `SELECT p.name, SUM(si.quantity)::int AS units_sold,
            COALESCE(SUM(si.quantity * si.unit_price), 0) AS revenue
     FROM sale_items si
     JOIN sales s ON s.id = si.sale_id AND s.company_id = $1
     JOIN products p ON p.id = si.product_id AND p.company_id = s.company_id
     WHERE s.sold_at::date BETWEEN $2::date AND $3::date
     GROUP BY p.id, p.name
     ORDER BY units_sold DESC
     LIMIT $4`,
    [companyId, start, end, safeLimit],
  );

  return { period, topProducts: result.rows };
}

async function search_products(companyId, { query: searchQuery, limit = 10 } = {}) {
  const safeLimit = Math.min(30, Math.max(1, Number(limit) || 10));
  const rawQuery = (typeof searchQuery === 'string' ? searchQuery : '').trim();

  if (!rawQuery) {
    const res = await query(
      `SELECT id, name, category, barcode, quantity, minimum_stock, purchase_price, selling_price, size, color, brand
       FROM products
       WHERE company_id = $1 AND deleted_at IS NULL
       ORDER BY quantity DESC
       LIMIT $2`,
      [companyId, safeLimit],
    );
    let rows = res.rows.map((r) => ({
      id: r.id,
      name: r.name,
      category: r.category,
      quantity: Number(r.quantity),
      selling_price: Number(r.selling_price),
      purchase_price: Number(r.purchase_price),
      minimum_stock: Number(r.minimum_stock),
      size: r.size,
      color: r.color,
      brand: r.brand,
    }));

    // If company has no retail products, check restaurant_menu_items
    if (rows.length === 0) {
      try {
        const menuRes = await query(
          `SELECT id, name, category, price, is_available
           FROM restaurant_menu_items
           WHERE company_id = $1 AND deleted_at IS NULL
           ORDER BY category NULLS LAST, name ASC
           LIMIT $2`,
          [companyId, safeLimit],
        );
        if (menuRes.rows.length > 0) {
          rows = menuRes.rows.map((r) => ({
            id: r.id,
            name: r.name,
            category: r.category,
            selling_price: Number(r.price),
            is_available: r.is_available,
            quantity: r.is_available ? 1 : 0,
            type: 'menu_item',
          }));
        }
      } catch (_) {}
    }

    return { found: rows.length > 0, query: '', count: rows.length, products: rows };
  }

  const aliasTerms = expandSearchAliases(rawQuery);
  const searchPatterns = Array.from(new Set([
    `%${rawQuery}%`,
    ...aliasTerms.map((t) => `%${t}%`),
  ])).slice(0, 10);

  const conditions = searchPatterns.map((_, i) => `(name ILIKE $${i + 2} OR category ILIKE $${i + 2} OR barcode ILIKE $${i + 2})`).join(' OR ');

  const result = await query(
    `SELECT id, name, category, barcode, quantity, minimum_stock, purchase_price, selling_price, size, color, brand
     FROM products
     WHERE company_id = $1 AND deleted_at IS NULL AND (${conditions})
     ORDER BY
       CASE WHEN LOWER(name) = LOWER($${searchPatterns.length + 2}) THEN 0
            WHEN name ILIKE $${searchPatterns.length + 3} THEN 1
            ELSE 2 END,
       quantity DESC
     LIMIT $${searchPatterns.length + 4}`,
    [companyId, ...searchPatterns, rawQuery, `%${rawQuery}%`, safeLimit],
  );

  let rows = result.rows.map((r) => ({
    id: r.id,
    name: r.name,
    category: r.category,
    quantity: Number(r.quantity),
    selling_price: Number(r.selling_price),
    purchase_price: Number(r.purchase_price),
    minimum_stock: Number(r.minimum_stock),
    size: r.size,
    color: r.color,
    brand: r.brand,
  }));

  // If no standard products found, check restaurant_menu_items
  if (rows.length === 0) {
    try {
      const menuConditions = searchPatterns.map((_, i) => `(name ILIKE $${i + 2} OR category ILIKE $${i + 2})`).join(' OR ');
      const restMenuRes = await query(
        `SELECT id, name, category, price, is_available
         FROM restaurant_menu_items
         WHERE company_id = $1 AND deleted_at IS NULL AND (${menuConditions})
         ORDER BY
           CASE WHEN LOWER(name) = LOWER($${searchPatterns.length + 2}) THEN 0
                WHEN name ILIKE $${searchPatterns.length + 3} THEN 1
                ELSE 2 END,
           name ASC
         LIMIT $${searchPatterns.length + 4}`,
        [companyId, ...searchPatterns, rawQuery, `%${rawQuery}%`, safeLimit],
      );
      if (restMenuRes.rows.length > 0) {
        rows = restMenuRes.rows.map((r) => ({
          id: r.id,
          name: r.name,
          category: r.category,
          selling_price: Number(r.price),
          is_available: r.is_available,
          quantity: r.is_available ? 1 : 0,
          type: 'menu_item',
        }));
      }
    } catch (_) {}
  }

  // If still no products found, check restaurant_inventory_items (ingredients)
  if (rows.length === 0) {
    try {
      const restRes = await query(
        `SELECT id, name, category, unit, quantity, minimum_stock, purchase_price, selling_price
         FROM restaurant_inventory_items
         WHERE company_id = $1 AND archived_at IS NULL AND (${conditions})
         LIMIT $${searchPatterns.length + 2}`,
        [companyId, ...searchPatterns, safeLimit],
      );
      if (restRes.rows.length > 0) {
        rows = restRes.rows.map((r) => ({
          id: r.id,
          name: r.name,
          category: r.category,
          unit: r.unit,
          quantity: Number(r.quantity),
          selling_price: r.selling_price != null ? Number(r.selling_price) : null,
          purchase_price: Number(r.purchase_price),
          minimum_stock: Number(r.minimum_stock),
        }));
      }
    } catch (_) {
      // Ignore if table not applicable
    }
  }

  return {
    found: rows.length > 0,
    query: rawQuery,
    count: rows.length,
    products: rows,
  };
}

async function get_product_stock(companyId, { productName, productId } = {}) {
  if (productId) {
    const res = await query(
      `SELECT id, name, category, quantity, minimum_stock, purchase_price, selling_price, size, color, brand
       FROM products
       WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
      [companyId, productId],
    );
    if (res.rows[0]) {
      const r = res.rows[0];
      return {
        found: true,
        product: {
          id: r.id,
          name: r.name,
          quantity: Number(r.quantity),
          selling_price: Number(r.selling_price),
          purchase_price: Number(r.purchase_price),
          minimum_stock: Number(r.minimum_stock),
          category: r.category,
          size: r.size,
          color: r.color,
          brand: r.brand,
        },
      };
    }
  }

  const nameToSearch = typeof productName === 'string' ? productName.trim() : '';
  if (!nameToSearch) {
    const fallbackRes = await query(
      `SELECT id, name, category, quantity, minimum_stock, purchase_price, selling_price
       FROM products
       WHERE company_id = $1 AND deleted_at IS NULL
       ORDER BY quantity DESC LIMIT 1`,
      [companyId],
    );
    if (fallbackRes.rows[0]) {
      const r = fallbackRes.rows[0];
      return {
        found: true,
        product: {
          id: r.id,
          name: r.name,
          quantity: Number(r.quantity),
          selling_price: Number(r.selling_price),
          purchase_price: Number(r.purchase_price),
          minimum_stock: Number(r.minimum_stock),
          category: r.category,
        },
      };
    }
    return { found: false, query: '' };
  }

  const searchRes = await search_products(companyId, { query: nameToSearch, limit: 10 });
  if (!searchRes.found || searchRes.products.length === 0) {
    return { found: false, query: nameToSearch };
  }

  if (searchRes.products.length === 1) {
    return {
      found: true,
      product: searchRes.products[0],
    };
  }

  // Exact name match check among multiple results
  const exactMatch = searchRes.products.find(
    (p) => p.name.trim().toLowerCase() === nameToSearch.toLowerCase(),
  );
  if (exactMatch) {
    return {
      found: true,
      product: exactMatch,
      otherMatches: searchRes.products.filter((p) => p.id !== exactMatch.id),
    };
  }

  return {
    found: true,
    multiple: true,
    query: nameToSearch,
    matchCount: searchRes.products.length,
    matches: searchRes.products,
  };
}

async function get_products(companyId, { filter = 'all', limit = 20, offset = 0 } = {}) {
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 20));
  const safeOffset = Math.max(0, Number(offset) || 0);

  let whereClause = 'WHERE company_id = $1 AND deleted_at IS NULL';
  if (filter === 'in_stock') {
    whereClause += ' AND quantity > 0';
  } else if (filter === 'low_stock') {
    whereClause += ' AND quantity <= minimum_stock AND quantity > 0';
  } else if (filter === 'out_of_stock') {
    whereClause += ' AND quantity = 0';
  }

  const [countRes, listRes] = await Promise.all([
    query(`SELECT COUNT(*)::int AS count FROM products ${whereClause}`, [companyId]),
    query(
      `SELECT id, name, category, quantity, minimum_stock, purchase_price, selling_price, size, color, brand
       FROM products
       ${whereClause}
       ORDER BY quantity DESC, name ASC
       LIMIT $2 OFFSET $3`,
      [companyId, safeLimit, safeOffset],
    ),
  ]);

  if (countRes.rows[0].count === 0) {
    try {
      let menuWhere = 'WHERE company_id = $1 AND deleted_at IS NULL';
      if (filter === 'in_stock') {
        menuWhere += ' AND is_available = true';
      } else if (filter === 'out_of_stock') {
        menuWhere += ' AND is_available = false';
      }
      const restMenu = await query(
        `SELECT id, name, category, price, is_available
         FROM restaurant_menu_items
         ${menuWhere}
         ORDER BY category NULLS LAST, name ASC
         LIMIT $2 OFFSET $3`,
        [companyId, safeLimit, safeOffset],
      );
      if (restMenu.rows.length > 0) {
        const countMenu = await query(
          `SELECT COUNT(*)::int AS count FROM restaurant_menu_items ${menuWhere}`,
          [companyId],
        );
        return {
          totalCount: countMenu.rows[0].count,
          filter,
          products: restMenu.rows.map((r) => ({
            id: r.id,
            name: r.name,
            category: r.category,
            selling_price: Number(r.price),
            is_available: r.is_available,
            quantity: r.is_available ? 1 : 0,
            type: 'menu_item',
          })),
        };
      }
    } catch (_) {}
  }

  return {
    totalCount: countRes.rows[0].count,
    filter,
    products: listRes.rows.map((r) => ({
      id: r.id,
      name: r.name,
      category: r.category,
      quantity: Number(r.quantity),
      selling_price: Number(r.selling_price),
      minimum_stock: Number(r.minimum_stock),
      size: r.size,
      color: r.color,
      brand: r.brand,
    })),
  };
}

async function get_inventory_summary(companyId) {
  const result = await query(
    `SELECT
       COUNT(*)::int AS total_products,
       COALESCE(SUM(quantity), 0)::int AS total_units,
       COUNT(*) FILTER (WHERE quantity = 0)::int AS out_of_stock,
       COUNT(*) FILTER (WHERE quantity <= minimum_stock AND quantity > 0)::int AS low_stock,
       COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * (COALESCE(selling_price, 0) - COALESCE(purchase_price, 0)) ELSE 0 END), 0)::numeric(14,2) AS total_inventory_value,
       COALESCE(SUM(quantity * purchase_price), 0)::numeric(14,2) AS total_cost_value
     FROM products
     WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );

  const row = result.rows[0];

  if (row.total_products === 0) {
    try {
      const restMenu = await query(
        `SELECT COUNT(*)::int AS total_items,
                COUNT(*) FILTER (WHERE is_available = true)::int AS available_items,
                COUNT(*) FILTER (WHERE is_available = false)::int AS unavailable_items,
                COALESCE(AVG(price), 0)::numeric(14,2) AS average_price
         FROM restaurant_menu_items
         WHERE company_id = $1 AND deleted_at IS NULL`,
        [companyId],
      );
      if (restMenu.rows[0].total_items > 0) {
        const r = restMenu.rows[0];
        return {
          totalProducts: r.total_items,
          totalUnits: r.available_items,
          outOfStockCount: r.unavailable_items,
          lowStockCount: 0,
          totalInventoryValue: 0,
          totalCostValue: 0,
          type: 'restaurant_menu',
        };
      }
    } catch (_) {}
  }

  return {
    totalProducts: row.total_products,
    totalUnits: row.total_units,
    outOfStockCount: row.out_of_stock,
    lowStockCount: row.low_stock,
    totalInventoryValue: Number(row.total_inventory_value),
    totalCostValue: Number(row.total_cost_value),
  };
}

async function get_low_stock_products(companyId) {
  const result = await query(
    `SELECT name, quantity, minimum_stock
     FROM products
     WHERE company_id = $1 AND deleted_at IS NULL AND quantity <= minimum_stock
     ORDER BY quantity ASC
     LIMIT 30`,
    [companyId],
  );
  return { lowStockProducts: result.rows };
}

/** Not business-type gated  -  `products.expiration_date` exists for
 * every company (migration 006), so this is useful for any account
 * that tracks perishables/expiry (pharmacy first, but also grocery/
 * supérette), same "harmless empty result elsewhere" rule as the
 * clinic/restaurant tools below. */
async function get_expiring_products(companyId, { days = 30 } = {}) {
  const safeDays = Math.min(365, Math.max(1, Number(days) || 30));
  const products = await pharmacyRepo.expiringProducts(companyId, safeDays, 30);
  return { days: safeDays, expiringProducts: products };
}

async function get_slow_moving_products(companyId, { days = 30 } = {}) {
  const safeDays = Math.min(365, Math.max(1, Number(days) || 30));

  const result = await query(
    `SELECT p.name, p.quantity,
            COALESCE(SUM(si.quantity), 0)::int AS units_sold_recently
     FROM products p
     LEFT JOIN sale_items si ON si.product_id = p.id
     LEFT JOIN sales s ON s.id = si.sale_id
       AND s.sold_at >= now() - ($2 || ' days')::interval
     WHERE p.company_id = $1 AND p.deleted_at IS NULL
     GROUP BY p.id, p.name, p.quantity
     HAVING COALESCE(SUM(si.quantity), 0) = 0
     ORDER BY p.quantity DESC
     LIMIT 20`,
    [companyId, safeDays],
  );

  return { days: safeDays, slowMovingProducts: result.rows };
}

async function get_expenses_summary(companyId, { period = 'this_month' } = {}) {
  const { start, end } = resolvePeriodRange(period);
  const [operatingExpenses, salaryExpenses] = await Promise.all([
    expensesRepo.totalForRange(companyId, start, end),
    employeesRepo.totalSalaryCostForRange(companyId, start, end),
  ]);
  return {
    period,
    operatingExpenses,
    employeeSalaries: salaryExpenses,
    total: operatingExpenses + salaryExpenses,
  };
}

async function calculate_profit(companyId, { period = 'this_month' } = {}) {
  const { start, end } = resolvePeriodRange(period);
  const [sales, opExpenses, salaryExpenses, creditPayments] = await Promise.all([
    salesTotals(companyId, start, end),
    expensesRepo.totalForRange(companyId, start, end),
    employeesRepo.totalSalaryCostForRange(companyId, start, end),
    creditRepo.totalPaymentsForRange(companyId, start, end),
  ]);
  const revenue = sales.revenue + creditPayments;
  const expenses = opExpenses + salaryExpenses;
  return {
    period,
    revenue,
    expenses,
    profit: Math.round((revenue - expenses) * 100) / 100,
  };
}

async function compare_periods(companyId, { periodA = 'this_month', periodB = 'last_month' } = {}) {
  const rangeA = resolvePeriodRange(periodA);
  const rangeB = resolvePeriodRange(periodB);
  const [totalsA, totalsB] = await Promise.all([
    salesTotals(companyId, rangeA.start, rangeA.end),
    salesTotals(companyId, rangeB.start, rangeB.end),
  ]);

  const growthPercentage =
    totalsB.revenue > 0
      ? Math.round(((totalsA.revenue - totalsB.revenue) / totalsB.revenue) * 1000) / 10
      : null;

  return {
    periodA: { period: periodA, ...totalsA },
    periodB: { period: periodB, ...totalsB },
    growthPercentage,
  };
}

async function get_unpaid_invoices(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count, COALESCE(SUM(total), 0) AS total_amount
     FROM invoices WHERE company_id = $1 AND status = 'unpaid'`,
    [companyId],
  );
  return {
    unpaidInvoicesCount: result.rows[0].count,
    unpaidInvoicesTotal: Number(result.rows[0].total_amount),
  };
}

async function get_customers_with_debt(companyId, { limit = 10 } = {}) {
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 10));
  const result = await query(
    `SELECT name, phone, balance_due
     FROM customers
     WHERE company_id = $1 AND deleted_at IS NULL AND balance_due > 0
     ORDER BY balance_due DESC
     LIMIT $2`,
    [companyId, safeLimit],
  );
  return { customersWithDebt: result.rows };
}

async function get_customers(companyId, { query: searchQuery, limit = 10 } = {}) {
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 10));
  if (searchQuery && typeof searchQuery === 'string' && searchQuery.trim().length > 0) {
    const q = `%${searchQuery.trim()}%`;
    const res = await query(
      `SELECT id, name, phone, address, balance_due
       FROM customers
       WHERE company_id = $1 AND deleted_at IS NULL AND (name ILIKE $2 OR phone ILIKE $2)
       ORDER BY balance_due DESC, name ASC
       LIMIT $3`,
      [companyId, q, safeLimit],
    );
    return { count: res.rows.length, customers: res.rows.map((r) => ({ ...r, balance_due: Number(r.balance_due) })) };
  }

  const res = await query(
    `SELECT id, name, phone, address, balance_due
     FROM customers
     WHERE company_id = $1 AND deleted_at IS NULL
     ORDER BY balance_due DESC, name ASC
     LIMIT $2`,
    [companyId, safeLimit],
  );
  return { count: res.rows.length, customers: res.rows.map((r) => ({ ...r, balance_due: Number(r.balance_due) })) };
}

async function get_customer_debt(companyId, { customerName } = {}) {
  const name = typeof customerName === 'string' ? customerName.trim() : '';
  if (!name) {
    const res = await query(
      `SELECT id, name, phone, balance_due
       FROM customers
       WHERE company_id = $1 AND deleted_at IS NULL AND balance_due > 0
       ORDER BY balance_due DESC
       LIMIT 1`,
      [companyId],
    );
    if (res.rows[0]) {
      return { found: true, matches: [{ ...res.rows[0], balance_due: Number(res.rows[0].balance_due) }] };
    }
    return { found: false, query: '' };
  }

  const q = `%${name}%`;
  const res = await query(
    `SELECT id, name, phone, balance_due
     FROM customers
     WHERE company_id = $1 AND deleted_at IS NULL AND name ILIKE $2
     ORDER BY balance_due DESC
     LIMIT 5`,
    [companyId, q],
  );
  if (res.rows.length === 0) {
    return { found: false, query: name };
  }
  return {
    found: true,
    matches: res.rows.map((r) => ({ ...r, balance_due: Number(r.balance_due) })),
  };
}

async function get_employees(companyId, { limit = 10 } = {}) {
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 10));
  const res = await query(
    `SELECT id, name, position, phone, base_salary, joined_at
     FROM employees
     WHERE company_id = $1 AND deleted_at IS NULL
     ORDER BY name ASC
     LIMIT $2`,
    [companyId, safeLimit],
  );
  return { count: res.rows.length, employees: res.rows.map((r) => ({ ...r, base_salary: Number(r.base_salary) })) };
}

async function get_appointments(companyId, { period = 'upcoming', limit = 10 } = {}) {
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 10));
  let whereDate = 'scheduled_at >= now()';
  if (period === 'today') {
    whereDate = 'scheduled_at::date = CURRENT_DATE';
  } else if (period === 'this_month') {
    whereDate = "scheduled_at::date >= date_trunc('month', CURRENT_DATE) AND scheduled_at::date <= CURRENT_DATE";
  }
  const res = await query(
    `SELECT a.id, a.title, a.scheduled_at, a.status, a.notes, c.name AS customer_name, c.phone AS customer_phone
     FROM appointments a
     LEFT JOIN customers c ON c.id = a.customer_id AND c.company_id = a.company_id
     WHERE a.company_id = $1 AND ${whereDate}
     ORDER BY a.scheduled_at ASC
     LIMIT $2`,
    [companyId, safeLimit],
  );
  return {
    period,
    count: res.rows.length,
    appointments: res.rows,
  };
}

async function get_suppliers(companyId) {
  // NOTE: the current schema has no purchases/supplier-transactions
  // table, so this tool can only report the supplier list itself  - 
  // not purchase volume or "which supplier do we buy most from"
  // (Ch. 7's supplier example). Documented as a known gap in
  // AI_MIGRATION.md rather than fabricated.
  const result = await query(
    `SELECT name, phone FROM suppliers WHERE company_id = $1 AND deleted_at IS NULL ORDER BY name`,
    [companyId],
  );
  return { suppliers: result.rows };
}

// ---------------------------------------------------------------------
// Clinic-specific tools (Ch. 3/23)  -  only ever return meaningful data
// for a company whose business_type is 'clinic'; for any other
// business these tables are simply empty, so the model naturally has
// nothing to report rather than needing to be told not to call these.
// ---------------------------------------------------------------------

async function get_clinic_queue_status(companyId) {
  const entries = await clinicRepo.getActiveQueue(companyId);
  const nextUp = entries.find((e) => e.status === 'waiting');
  return {
    waitingCount: entries.filter((e) => e.status === 'waiting').length,
    inConsultation: entries.find((e) => e.status === 'in_consultation')?.patient_name ?? null,
    nextPatient: nextUp ? nextUp.patient_name : null,
    queue: entries.map((e) => ({ position: e.position, patientName: e.patient_name, status: e.status })),
  };
}

async function get_clinic_dashboard(companyId) {
  // Reuses the same service.getDashboard the Clinic dashboard screen
  // calls (not just clinicRepo.dashboardStats' patient/appointment
  // counts), so the model can also answer revenue/profit/outstanding-
  // payments questions with the exact same numbers the UI shows  - 
  // single source of truth, per Ch. 21.
  return clinicService.getDashboard(companyId);
}

async function get_patient_last_visit(companyId, { patientName } = {}) {
  if (!patientName || typeof patientName !== 'string') {
    return { error: 'patientName is required' };
  }
  const result = await query(
    `SELECT cv.visited_at, cv.reason, cv.diagnosis, cv.treatment, cv.follow_up_date
     FROM clinic_visits cv
     JOIN clinic_patients cp ON cp.id = cv.patient_id AND cp.company_id = cv.company_id
     WHERE cv.company_id = $1 AND cp.full_name ILIKE $2
     ORDER BY cv.visited_at DESC
     LIMIT 1`,
    [companyId, `%${patientName}%`],
  );
  return { lastVisit: result.rows[0] || null };
}

// ---------------------------------------------------------------------
// Restaurant-specific tools (Ch. 17/23)  -  same pattern as the Clinic
// tools above: only meaningful for a company whose business_type is
// 'restaurant', harmlessly empty otherwise.
// ---------------------------------------------------------------------

async function get_restaurant_dashboard(companyId) {
  // Reuses the same service.getDashboard the Restaurant dashboard
  // screen calls, so the model's revenue/profit answers always match
  // the UI exactly (Ch. 21's single-source-of-truth rule).
  return restaurantService.getDashboard(companyId);
}

async function get_restaurant_tables_status(companyId) {
  const tables = await restaurantRepo.findAllTables(companyId);
  return {
    total: tables.length,
    occupied: tables.filter((t) => t.status === 'occupied').length,
    available: tables.filter((t) => t.status === 'available').length,
    tables: tables.map((t) => ({ name: t.name, status: t.status, seats: t.seats })),
  };
}

async function get_restaurant_active_orders(companyId) {
  const orders = await restaurantRepo.getActiveOrders(companyId);
  return {
    count: orders.length,
    orders: orders.map((o) => ({
      orderNumber: o.order_number,
      tableName: o.table_name,
      status: o.status,
      totalAmount: Number(o.total_amount),
    })),
  };
}

async function get_restaurant_menu(companyId, { category, availableOnly = false } = {}) {
  let where = 'company_id = $1 AND deleted_at IS NULL';
  const params = [companyId];
  if (availableOnly) {
    where += ' AND is_available = true';
  }
  if (category && typeof category === 'string' && category.trim()) {
    params.push(`%${category.trim()}%`);
    where += ` AND category ILIKE $${params.length}`;
  }
  const result = await query(
    `SELECT id, name, category, price, is_available
     FROM restaurant_menu_items
     WHERE ${where}
     ORDER BY category NULLS LAST, name ASC`,
    params,
  );

  if (result.rows.length > 0) {
    return {
      totalItems: result.rows.length,
      menu: result.rows.map((r) => ({
        id: r.id,
        name: r.name,
        category: r.category,
        price: Number(r.price),
        isAvailable: r.is_available,
      })),
    };
  }

  // Fallback: If no restaurant_menu_items exist, look in products
  // (e.g. for superette, grocery, café, or retail stores where items are stored in products)
  try {
    let prodWhere = 'company_id = $1 AND deleted_at IS NULL';
    const prodParams = [companyId];
    if (availableOnly) {
      prodWhere += ' AND quantity > 0';
    }
    if (category && typeof category === 'string' && category.trim()) {
      prodParams.push(`%${category.trim()}%`);
      prodWhere += ` AND category ILIKE $${prodParams.length}`;
    }
    const prodResult = await query(
      `SELECT id, name, category, selling_price, quantity
       FROM products
       WHERE ${prodWhere}
       ORDER BY category NULLS LAST, name ASC`,
      prodParams,
    );
    if (prodResult.rows.length > 0) {
      return {
        totalItems: prodResult.rows.length,
        menu: prodResult.rows.map((r) => ({
          id: r.id,
          name: r.name,
          category: r.category,
          price: Number(r.selling_price),
          isAvailable: Number(r.quantity) > 0,
        })),
      };
    }
  } catch (_) {}

  return {
    totalItems: 0,
    menu: [],
  };
}

// ---------------------------------------------------------------------
// Pharmacy-specific tool (Ch. 15)  -  reuses the exact same
// pharmacy.service.getDashboard the Pharmacy dashboard screen calls,
// so revenue/profit answers always match the UI (Ch. 21).
// ---------------------------------------------------------------------

async function get_pharmacy_dashboard(companyId) {
  return pharmacyService.getDashboard(companyId);
}

// ---------------------------------------------------------------------
// Supérette / general-retail tool (Ch. 16)  -  reuses the exact same
// superette.service.getDashboard the Supérette dashboard screen calls,
// so revenue/profit/debt answers always match the UI (Ch. 21).
// ---------------------------------------------------------------------

async function get_superette_dashboard(companyId) {
  return superetteService.getDashboard(companyId);
}

// ---------------------------------------------------------------------
// Enterprise / Company tool (Ch. 19)  -  reuses the exact same
// enterprise.service.getDashboard the Enterprise dashboard screen
// calls, so revenue/profit/invoice/project answers always match the UI.
// ---------------------------------------------------------------------

async function get_enterprise_dashboard(companyId) {
  return enterpriseService.getDashboard(companyId);
}

// ---------------------------------------------------------------------
// Clothing store tool (Ch. 18)  -  reuses the exact same
// clothing.service.getDashboard the Clothing dashboard screen calls,
// so revenue/profit/debt answers always match the UI (Ch. 21).
// ---------------------------------------------------------------------

async function get_clothing_dashboard(companyId) {
  return clothingService.getDashboard(companyId);
}

const TOOL_IMPLEMENTATIONS = {
  get_sales_summary,
  get_sales,
  get_top_products,
  search_products,
  get_product_stock,
  get_products,
  get_inventory_summary,
  get_low_stock_products,
  get_expiring_products,
  get_slow_moving_products,
  get_expenses_summary,
  calculate_profit,
  compare_periods,
  get_unpaid_invoices,
  get_customers,
  get_customer_debt,
  get_customers_with_debt,
  get_suppliers,
  get_employees,
  get_appointments,
  get_clinic_queue_status,
  get_clinic_dashboard,
  get_patient_last_visit,
  get_restaurant_dashboard,
  get_restaurant_tables_status,
  get_restaurant_active_orders,
  get_restaurant_menu,
  get_pharmacy_dashboard,
  get_superette_dashboard,
  get_clothing_dashboard,
  get_enterprise_dashboard,
};

// OpenAI-compatible tool/function schema  -  sent as the `tools` param.
// Kept intentionally small and specific (Ch. 23: don't send unnecessary
// data/complexity to the model) rather than one giant generic
// "run_query" escape hatch, which is exactly the "unrestricted direct
// database access" Ch. 7 says never to give the LLM.
const PERIOD_ENUM = ['today', 'yesterday', 'this_month', 'last_month', 'this_year'];

const TOOL_DEFINITIONS = [
  {
    type: 'function',
    function: {
      name: 'get_sales_summary',
      description: 'Get total revenue, order count, and average order value for a period.',
      parameters: {
        type: 'object',
        properties: { period: { type: 'string', enum: PERIOD_ENUM } },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_sales',
      description: 'Get recent sales transactions, orders, and payment statuses for a period.',
      parameters: {
        type: 'object',
        properties: {
          period: { type: 'string', enum: PERIOD_ENUM, description: 'Period to look for, default today' },
          limit: { type: 'integer', description: 'Max sales to return, default 10' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_products',
      description: 'Search products by name, barcode, or category. Supports Arabic, French, and English aliases (e.g. hlib, lait, حليب, gazoz). Returns matching products with quantities, selling prices, and category.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Product name or search keyword' },
          limit: { type: 'integer', description: 'Max products to return, default 10' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_product_stock',
      description: 'Get exact current stock quantity, selling price, and details for a specific product by name or ID. Always use this when the user asks about a specific product availability, stock, or price.',
      parameters: {
        type: 'object',
        properties: {
          productName: { type: 'string', description: 'Name of the product (e.g. "حليب", "hlib", "lait", "Coca-Cola")' },
          productId: { type: 'string', description: 'Optional UUID of the product' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_products',
      description: 'List products in inventory. Can filter by in_stock, low_stock, out_of_stock, or all. Always use this when asked what products exist, what is in stock, or to list inventory.',
      parameters: {
        type: 'object',
        properties: {
          filter: { type: 'string', enum: ['all', 'in_stock', 'low_stock', 'out_of_stock'], description: 'Filter products by stock status' },
          limit: { type: 'integer', description: 'Max products to return, default 20' },
          offset: { type: 'integer', description: 'Pagination offset, default 0' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_inventory_summary',
      description: 'Get overall inventory statistics: total number of distinct products, total units in stock, out-of-stock count, low-stock count, and total inventory valuation.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_customers',
      description: 'List or search customers registered in the business, including their phone numbers and balance due.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Optional search keyword for customer name or phone' },
          limit: { type: 'integer', description: 'Max customers to return, default 10' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_customer_debt',
      description: 'Get current balance due / debt for a specific customer by name.',
      parameters: {
        type: 'object',
        properties: {
          customerName: { type: 'string', description: 'Name of the customer' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_employees',
      description: 'List employees, their job positions, and base salaries.',
      parameters: {
        type: 'object',
        properties: {
          limit: { type: 'integer', description: 'Max employees to return, default 10' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_appointments',
      description: 'List scheduled appointments, dates, statuses, and associated customer names.',
      parameters: {
        type: 'object',
        properties: {
          period: { type: 'string', enum: ['today', 'upcoming', 'this_month'], description: 'Period filter, default upcoming' },
          limit: { type: 'integer', description: 'Max appointments to return, default 10' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_top_products',
      description: 'Get the best-selling products (by units sold) for a period.',
      parameters: {
        type: 'object',
        properties: {
          period: { type: 'string', enum: PERIOD_ENUM },
          limit: { type: 'integer', description: 'Max products to return, default 5' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_low_stock_products',
      description: 'Get products at or below their minimum stock threshold right now.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_expiring_products',
      description: "Get products whose expiration date falls within the given number of days (default 30) — mainly for pharmacy/grocery accounts that track expiry.",
      parameters: {
        type: 'object',
        properties: { days: { type: 'integer', description: 'How many days ahead to look, default 30' } },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_slow_moving_products',
      description: 'Get products that have not sold at all in the last N days ("stuck" inventory).',
      parameters: {
        type: 'object',
        properties: { days: { type: 'integer', description: 'Lookback window, default 30' } },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_expenses_summary',
      description: 'Get total expenses (operating + employee salaries) for a period.',
      parameters: {
        type: 'object',
        properties: { period: { type: 'string', enum: PERIOD_ENUM } },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'calculate_profit',
      description: 'Get revenue, expenses, and net profit for a period. Always use this instead of computing profit yourself.',
      parameters: {
        type: 'object',
        properties: { period: { type: 'string', enum: PERIOD_ENUM } },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'compare_periods',
      description: 'Compare sales between two periods, including growth percentage.',
      parameters: {
        type: 'object',
        properties: {
          periodA: { type: 'string', enum: PERIOD_ENUM },
          periodB: { type: 'string', enum: PERIOD_ENUM },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_unpaid_invoices',
      description: 'Get the count and total amount of currently unpaid invoices.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_customers_with_debt',
      description: 'Get customers who currently owe money (Credit Sale balance), highest debt first.',
      parameters: {
        type: 'object',
        properties: { limit: { type: 'integer', description: 'Max customers to return, default 10' } },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_suppliers',
      description: 'Get the list of registered suppliers (name/phone only — purchase history is not tracked yet).',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_clinic_queue_status',
      description: "Clinic businesses only: who's waiting right now, who's the next patient, who's currently in consultation.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_clinic_dashboard',
      description: 'Clinic businesses only: today\'s patient/appointment/queue counts.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_patient_last_visit',
      description: "Clinic businesses only: a named patient's most recent visit (reason, diagnosis, treatment, follow-up date).",
      parameters: {
        type: 'object',
        properties: { patientName: { type: 'string', description: 'The patient\'s name (partial match is fine)' } },
        required: ['patientName'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_restaurant_dashboard',
      description: "Restaurant businesses only: today's orders, tables, reservations, revenue and profit.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_restaurant_tables_status',
      description: 'Restaurant businesses only: which tables are occupied vs available right now.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_restaurant_active_orders',
      description: "Restaurant businesses only: today's still-open orders (pending/preparing/ready/served) and their status.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_restaurant_menu',
      description: 'Restaurant and Café businesses: list all dishes, drinks, meals, prices, categories, and availability on the menu.',
      parameters: {
        type: 'object',
        properties: {
          category: { type: 'string', description: 'Optional category name to filter by.' },
          availableOnly: { type: 'boolean', description: 'Set to true to return only available menu items.' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_pharmacy_dashboard',
      description: "Pharmacy businesses only: today's sales, gross/net profit, low-stock and expiring products, and inventory value.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_superette_dashboard',
      description: "Supérette/general-store businesses only: today's sales, gross/net profit, low-stock products, stock value, best-sellers, and outstanding customer debt/credit.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_clothing_dashboard',
      description: "Clothing-store businesses only: today's sales, gross/net profit, low-stock items (with size/color/brand), stock value, best-sellers, stock by category, and outstanding customer debt/credit.",
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_enterprise_dashboard',
      description: "Company/enterprise businesses only: today/week/month revenue, expenses (incl. payroll) and net profit, unpaid invoices, client and employee counts, and project status (active, on hold, overdue).",
      parameters: { type: 'object', properties: {} },
    },
  },
];

/**
 * Dispatches a tool call by name. `companyId` comes from the
 * authenticated request only (see security note above)  -  `args` comes
 * from the model and is treated as untrusted input to each tool
 * implementation (each function clamps/validates its own args, e.g.
 * `limit`/`days` bounds above).
 */
async function executeTool(companyId, toolName, args) {
  if (
    typeof toolName !== 'string' ||
    !Object.prototype.hasOwnProperty.call(TOOL_IMPLEMENTATIONS, toolName)
  ) {
    return { error: `Unknown tool: ${toolName}` };
  }
  const impl = TOOL_IMPLEMENTATIONS[toolName];
  try {
    return await impl(companyId, args || {});
  } catch (err) {
    return { error: `Tool ${toolName} failed: ${err.message}` };
  }
}

module.exports = {
  TOOL_DEFINITIONS,
  executeTool,
};

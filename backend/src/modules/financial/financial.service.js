const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const expensesRepo = require('../expenses/expenses.repository');
const employeesRepo = require('../employees/employees.repository');
const creditRepo = require('../credit/credit.repository');
const clinicRepo = require('../clinic/clinic.repository');
const restaurantRepo = require('../restaurant/restaurant.repository');

const PRESET_PERIODS = ['daily', 'weekly', 'monthly', 'yearly'];

function toDateStr(d) {
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Resolves a request into a concrete [rangeStart, rangeEnd] (both inclusive date strings).
 * Supports explicit parameters:
 * - date (YYYY-MM-DD) for daily
 * - month (YYYY-MM) for monthly
 * - year (YYYY) for yearly
 * - from / to for custom
 */
function resolveRange({ period, from, to, date, month, year } = {}) {
  if (from || to) {
    const start = new Date(from);
    const end = new Date(to);

    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw ApiError.badRequest(
        'from/to must be valid dates (YYYY-MM-DD)',
        'VALIDATION_ERROR',
      );
    }

    if (end < start) {
      throw ApiError.badRequest('to cannot be before from', 'VALIDATION_ERROR');
    }

    return {
      period: 'custom',
      rangeStart: toDateStr(start),
      rangeEnd: toDateStr(end),
    };
  }

  const resolvedPeriod = period || 'monthly';

  if (!PRESET_PERIODS.includes(resolvedPeriod)) {
    throw ApiError.badRequest(
      'period must be daily, weekly, monthly, or yearly (or pass from/to for a custom range)',
      'VALIDATION_ERROR',
    );
  }

  const now = new Date();
  const todayStr = toDateStr(now);
  let rangeStart;
  let rangeEnd;

  switch (resolvedPeriod) {
    case 'daily': {
      if (date && /^\d{4}-\d{2}-\d{2}$/.test(date)) {
        rangeStart = date;
        rangeEnd = date;
      } else {
        rangeStart = todayStr;
        rangeEnd = todayStr;
      }
      break;
    }
    case 'weekly': {
      const dayOfWeek = now.getUTCDay(); // 0 = Sun, 1 = Mon, ..., 6 = Sat
      const diffToMonday = (dayOfWeek + 6) % 7;
      const monday = new Date(now);
      monday.setUTCDate(now.getUTCDate() - diffToMonday);
      const sunday = new Date(monday);
      sunday.setUTCDate(monday.getUTCDate() + 6);
      rangeStart = toDateStr(monday);
      rangeEnd = toDateStr(sunday);
      break;
    }
    case 'yearly': {
      const y = year ? parseInt(year, 10) : now.getUTCFullYear();
      if (!y || Number.isNaN(y)) {
        throw ApiError.badRequest('Invalid year provided', 'VALIDATION_ERROR');
      }
      rangeStart = `${y}-01-01`;
      rangeEnd = `${y}-12-31`;
      break;
    }
    case 'monthly':
    default: {
      if (month && /^\d{4}-\d{1,2}$/.test(month)) {
        const [yStr, mStr] = month.split('-');
        const y = parseInt(yStr, 10);
        const m = parseInt(mStr, 10);
        const monthStart = new Date(Date.UTC(y, m - 1, 1));
        const monthEnd = new Date(Date.UTC(y, m, 0));
        rangeStart = toDateStr(monthStart);
        rangeEnd = toDateStr(monthEnd);
      } else {
        const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
        const monthEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0));
        rangeStart = toDateStr(monthStart);
        rangeEnd = toDateStr(monthEnd);
      }
      break;
    }
  }

  return { period: resolvedPeriod, rangeStart, rangeEnd };
}

/**
 * Single Authoritative Financial Calculation Service.
 *
 * Core Financial Rules:
 * 1. ACTUAL TRANSACTIONS ONLY: NEVER prorate, distribute across days/weeks, or estimate.
 * 2. Operating Expenses = SUM(actual non-salary expense transactions in period)
 * 3. Employee Salaries = SUM(actual salary expense transactions in period)
 * 4. Total Expenses = Operating Expenses + Employee Salaries
 * 5. Net Profit = Total Revenue - Total Expenses
 * 6. GLOBAL NET PROFIT: Unfiltered all-time balance = All Revenue - All Expenses.
 */
async function calculateFinancials(companyId, params = {}) {
  const { period, rangeStart, rangeEnd } = resolveRange(params);

  const companyRes = await query(
    `SELECT business_type FROM companies WHERE id = $1`,
    [companyId],
  );
  const company = companyRes.rows[0];
  if (!company) {
    throw ApiError.notFound('Company not found');
  }
  if (!company.business_type) {
    throw ApiError.forbidden(
      'Business onboarding is incomplete. Please complete business setup first.',
      'ONBOARDING_INCOMPLETE',
    );
  }
  const businessType = company.business_type;

  // 1. Global Totals (ALL ACTUAL TRANSACTIONS in system, unfiltered by period)
  const [
    globalSalesRes,
    globalCreditRes,
    globalClinicRes,
    globalRestaurantRes,
    globalExpensesRes,
    globalInventoryRes,
  ] = await Promise.all([
    query(
      `SELECT
         COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid'), 0) AS revenue,
         COALESCE(
           (
             SELECT SUM(si.unit_cost * si.quantity)
             FROM sale_items si
             JOIN sales s ON s.id = si.sale_id
             WHERE s.company_id = $1 AND s.payment_status != 'cancelled'
           ),
           0
         ) AS cogs
       FROM sales
       WHERE company_id = $1 AND payment_status != 'cancelled'`,
      [companyId],
    ),
    creditRepo.totalPaymentsForRange(companyId, '2000-01-01', '2100-12-31').catch(() => 0),
    clinicRepo.revenueForRange(companyId, '2000-01-01', '2100-12-31').catch(() => 0),
    restaurantRepo.revenueForRange(companyId, '2000-01-01', '2100-12-31').catch(() => 0),
    query(
      `SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE company_id = $1 AND deleted_at IS NULL`,
      [companyId],
    ),
    query(
      `SELECT COALESCE(SUM(
         CASE
           WHEN quantity > 0 THEN quantity * (COALESCE(selling_price, 0) - COALESCE(purchase_price, 0))
           ELSE 0
         END
       ), 0) AS inventory_value
       FROM products
       WHERE company_id = $1 AND deleted_at IS NULL`,
      [companyId],
    ),
  ]);

  const allRevenue =
    Number(globalSalesRes.rows[0]?.revenue || 0) +
    Number(globalCreditRes || 0) +
    Number(globalClinicRes || 0) +
    Number(globalRestaurantRes || 0);

  const globalCogs = Number(globalSalesRes.rows[0]?.cogs || 0);
  const allExpenses = Number(globalExpensesRes.rows[0]?.total || 0);
  let globalNetProfit = allRevenue - globalCogs - allExpenses;
  if (businessType === 'restaurant' || businessType === 'cafe') {
    // In restaurant model, dishes do not carry retail purchase costs (COGS = 0).
    // Inventory purchases affect Net Profit as expenses in this model.
    globalNetProfit = allRevenue - allExpenses;
  }
  const inventoryValue = Number(globalInventoryRes.rows[0]?.inventory_value || 0);

  // 2. Period Calculations (Aggregating actual transactions within rangeStart..rangeEnd)
  const [
    salesResult,
    topProductsResult,
    salaryTotal,
    operatingExpensesTotal,
    creditPaymentsTotal,
    clinicRevenueTotal,
    restaurantRevenueTotal,
    expensesCountRes,
    employeesRes,
    invoicesCountRes,
    salaryBreakdownList,
  ] = await Promise.all([
    query(
      `SELECT
         COALESCE(SUM(s.total) FILTER (WHERE s.payment_status = 'paid'), 0) AS revenue,
         COALESCE(
           (
             SELECT SUM(si.unit_cost * si.quantity)
             FROM sale_items si
             JOIN sales s2 ON s2.id = si.sale_id
             WHERE s2.company_id = $1
               AND s2.sold_at::date BETWEEN $2::date AND $3::date
               AND s2.payment_status != 'cancelled'
           ),
           0
         ) AS cogs,
         COUNT(*) FILTER (WHERE s.payment_status != 'cancelled')::int AS sales_count
       FROM sales s
       WHERE s.company_id = $1
         AND s.sold_at::date BETWEEN $2::date AND $3::date`,
      [companyId, rangeStart, rangeEnd],
    ),
    query(
      `SELECT
         p.name,
         SUM(si.quantity)::int AS units_sold,
         COALESCE(SUM(si.line_total), 0) AS total
       FROM sale_items si
       JOIN sales s ON s.id = si.sale_id AND s.company_id = $1
       JOIN products p ON p.id = si.product_id AND p.company_id = s.company_id
       WHERE s.company_id = $1
         AND s.sold_at::date BETWEEN $2::date AND $3::date
         AND s.payment_status != 'cancelled'
       GROUP BY p.id, p.name
       ORDER BY units_sold DESC
       LIMIT 5`,
      [companyId, rangeStart, rangeEnd],
    ),
    employeesRepo.totalSalaryCostForRange(companyId, rangeStart, rangeEnd),
    expensesRepo.totalForRange(companyId, rangeStart, rangeEnd, { excludeSalaryCategories: true }),
    creditRepo.totalPaymentsForRange(companyId, rangeStart, rangeEnd),
    clinicRepo.revenueForRange(companyId, rangeStart, rangeEnd),
    restaurantRepo.revenueForRange(companyId, rangeStart, rangeEnd),
    query(
      `SELECT COUNT(*)::int AS count
       FROM expenses
       WHERE company_id = $1 AND deleted_at IS NULL
         AND expense_date BETWEEN $2::date AND $3::date`,
      [companyId, rangeStart, rangeEnd],
    ),
    query(
      `SELECT id, name, position, base_salary
       FROM employees
       WHERE company_id = $1 AND deleted_at IS NULL
       ORDER BY name ASC`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count
       FROM invoices
       WHERE company_id = $1
         AND created_at::date BETWEEN $2::date AND $3::date`,
      [companyId, rangeStart, rangeEnd],
    ),
    typeof expensesRepo.salariesBreakdownForRange === 'function'
      ? expensesRepo.salariesBreakdownForRange(companyId, rangeStart, rangeEnd).catch(() => [])
      : Promise.resolve([]),
  ]);


  const employeesList = employeesRes.rows || [];

  let salesCount = Number(salesResult.rows[0]?.sales_count || 0);
  let topProducts = (topProductsResult.rows || []).map((r) => ({
    name: r.name,
    units_sold: Number(r.units_sold || 0),
    total: Number(r.total || 0),
  }));
  let cogsTotal = 0;

  if (businessType === 'restaurant' || businessType === 'cafe') {
    const [roCountRes, roDishes] = await Promise.all([
      query(
        `SELECT COUNT(*)::int AS count FROM restaurant_orders
         WHERE company_id = $1 AND created_at::date BETWEEN $2::date AND $3::date AND status != 'cancelled'`,
        [companyId, rangeStart, rangeEnd],
      ),
      restaurantRepo.bestSellingDishes(companyId, rangeStart, rangeEnd, 5),
    ]);
    salesCount = Number(roCountRes.rows[0]?.count || 0);
    topProducts = (roDishes || []).map((d) => ({
      name: d.item_name,
      units_sold: Number(d.units_sold || 0),
      total: Number(d.revenue || 0),
    }));
    // In the agreed restaurant model, dishes do not carry retail-style purchase costs (COGS = 0).
    // Gross Profit equals recorded revenue. Inventory purchases affect Net Profit as expenses.
    cogsTotal = 0;
  } else if (businessType === 'clinic') {
    const visitsCountRes = await query(
      `SELECT COUNT(*)::int AS count FROM clinic_visits
       WHERE company_id = $1 AND visited_at::date BETWEEN $2::date AND $3::date`,
      [companyId, rangeStart, rangeEnd],
    );
    salesCount = Number(visitsCountRes.rows[0]?.count || 0);
    cogsTotal = 0;
  } else {
    cogsTotal = Number(salesResult.rows[0]?.cogs || 0);
  }

  const coreSalesRevenue = Number(salesResult.rows[0]?.revenue || 0);
  const creditRev = Number(creditPaymentsTotal || 0);
  const clinicRev = Number(clinicRevenueTotal || 0);
  const restaurantRev = Number(restaurantRevenueTotal || 0);
  const revenue = coreSalesRevenue + creditRev + clinicRev + restaurantRev;

  const operatingExpenses = Number(operatingExpensesTotal || 0);
  const employeeSalaries = Number(salaryTotal || 0);
  // Strict formula: TOTAL EXPENSES = ALL BUSINESS EXPENSES + ACTUAL SALARY TRANSACTIONS
  const totalExpenses = operatingExpenses + employeeSalaries;

  const grossProfit = revenue - cogsTotal;
  const netProfit = grossProfit - totalExpenses;
  const profitMargin = revenue > 0 ? Number(((netProfit / revenue) * 100).toFixed(2)) : 0;

  // Operating Expenses Breakdown by Category (excluding salary categories)
  const catExpensesRes = await query(
    `SELECT category, COALESCE(SUM(amount), 0) AS total
     FROM expenses
     WHERE company_id = $1 AND deleted_at IS NULL
       AND expense_date BETWEEN $2::date AND $3::date
       AND NOT (category ILIKE '%salary%' OR category ILIKE '%salair%' OR category ILIKE '%payroll%' OR category ILIKE '%paie%' OR category ILIKE '%wage%' OR employee_id IS NOT NULL)
     GROUP BY category
     ORDER BY total DESC`,
    [companyId, rangeStart, rangeEnd],
  );

  const expensesByCategory = catExpensesRes.rows.map((r) => ({
    category: r.category || 'General Expense',
    amount: Number(r.total),
    total: Number(r.total),
  }));

  // Employee Salaries Breakdown: based on ACTUAL salary transactions in this period
  const employeeSalariesBreakdown = (salaryBreakdownList && salaryBreakdownList.length > 0)
    ? salaryBreakdownList
    : (Number(salaryTotal) > 0 && employeesList.length > 0
        ? employeesList.map((emp) => ({
            id: emp.id,
            name: emp.name,
            position: emp.position,
            baseSalary: Number(emp.base_salary || 0),
            periodSalary: Number(emp.base_salary || salaryTotal),
          }))
        : []);


  // Activity summary
  const activitySummary = {
    salesCount,
    expensesCount: Number(expensesCountRes.rows[0]?.count || 0),
    employeesCount: employeesList.length,
    invoicesCount: Number(invoicesCountRes.rows[0]?.count || 0),
  };

  // Recent transactions (sales + expenses + salaries) for period
  const [recentSalesRes, recentExpensesRes] = await Promise.all([
    query(
      `SELECT s.id, 'sale' AS type,
              COALESCE((
                SELECT SUM(COALESCE(si.line_profit, (si.unit_price - si.unit_cost) * si.quantity))
                FROM sale_items si
                WHERE si.sale_id = s.id
              ), s.total) AS amount,
              s.payment_status AS status, s.sold_at AS date,
              'Vente #' || SUBSTRING(s.id::text, 1, 8) AS title,
              'Vente' AS description
       FROM sales s
       WHERE s.company_id = $1 AND s.sold_at::date BETWEEN $2::date AND $3::date
         AND s.payment_status != 'cancelled'
       ORDER BY s.sold_at DESC
       LIMIT 25`,
      [companyId, rangeStart, rangeEnd],
    ),
    query(
      `SELECT e.id,
              CASE
                WHEN e.category ILIKE '%salary%' OR e.category ILIKE '%salair%' OR e.category ILIKE '%payroll%' OR e.category ILIKE '%paie%' OR e.category ILIKE '%wage%' OR e.employee_id IS NOT NULL THEN 'salary'
                ELSE 'expense'
              END AS type,
              e.amount,
              e.category AS status,
              e.expense_date::timestamp AS date,
              CASE
                WHEN e.employee_id IS NOT NULL THEN 'Salaire - ' || COALESCE(emp.name, e.description, 'Employé')
                ELSE e.category || COALESCE(' - ' || e.description, '')
              END AS title,
              e.description,
              emp.name AS employee_name,
              e.salary_period,
              e.duration
       FROM expenses e
       LEFT JOIN employees emp ON emp.id = e.employee_id AND emp.company_id = e.company_id
       WHERE e.company_id = $1 AND e.deleted_at IS NULL
         AND e.expense_date BETWEEN $2::date AND $3::date
       ORDER BY e.expense_date DESC, e.created_at DESC
       LIMIT 25`,
      [companyId, rangeStart, rangeEnd],
    ),
  ]);

  const recentTransactions = [
    ...(recentSalesRes.rows || []).map((r) => ({
      id: r.id,
      type: 'sale',
      amount: Number(r.amount),
      status: r.status,
      date: r.date,
      title: r.title,
      description: r.description,
    })),
    ...(recentExpensesRes.rows || []).map((r) => ({
      id: r.id,
      type: r.type,
      amount: Number(r.amount),
      status: r.status,
      date: r.date,
      title: r.title,
      description: r.description,
      employeeName: r.employee_name,
      salaryPeriod: r.salary_period,
      duration: r.duration,
    })),
  ].sort((a, b) => new Date(b.date) - new Date(a.date)).slice(0, 30);

  // 3. Yearly Monthly Breakdown (for Yearly reports: months 1 to 12)
  let monthlyBreakdown = [];
  if (period === 'yearly') {
    const targetYear = new Date(rangeStart).getUTCFullYear();
    const [salesByMonthRes, creditByMonthRes, clinicByMonthRes, restByMonthRes, expByMonthRes] =
      await Promise.all([
        query(
          `SELECT EXTRACT(MONTH FROM s.sold_at)::int AS month,
                  COALESCE(SUM(s.total) FILTER (WHERE s.payment_status = 'paid'), 0) AS revenue
           FROM sales s
           WHERE s.company_id = $1 AND EXTRACT(YEAR FROM s.sold_at) = $2
             AND s.payment_status != 'cancelled'
           GROUP BY month`,
          [companyId, targetYear],
        ),
        query(
          `SELECT EXTRACT(MONTH FROM paid_at)::int AS month, COALESCE(SUM(amount), 0) AS revenue
           FROM credit_payments
           WHERE company_id = $1 AND EXTRACT(YEAR FROM paid_at) = $2
           GROUP BY month`,
          [companyId, targetYear],
        ).catch(() => ({ rows: [] })),
        query(
          `SELECT EXTRACT(MONTH FROM visited_at)::int AS month, COALESCE(SUM(fee), 0) AS revenue
           FROM clinic_visits
           WHERE company_id = $1 AND EXTRACT(YEAR FROM visited_at) = $2
           GROUP BY month`,
          [companyId, targetYear],
        ).catch(() => ({ rows: [] })),
        query(
          `SELECT EXTRACT(MONTH FROM paid_at)::int AS month, COALESCE(SUM(amount), 0) AS revenue
           FROM restaurant_payments
           WHERE company_id = $1 AND EXTRACT(YEAR FROM paid_at) = $2
           GROUP BY month`,
          [companyId, targetYear],
        ).catch(() => ({ rows: [] })),
        query(
          `SELECT
             EXTRACT(MONTH FROM expense_date)::int AS month,
             COALESCE(SUM(amount), 0) AS total_expenses,
             COALESCE(SUM(amount) FILTER (
               WHERE category ILIKE '%salary%' OR category ILIKE '%salair%' OR category ILIKE '%payroll%' OR category ILIKE '%paie%' OR category ILIKE '%wage%' OR employee_id IS NOT NULL
             ), 0) AS salary_expenses,
             COALESCE(SUM(amount) FILTER (
               WHERE NOT (category ILIKE '%salary%' OR category ILIKE '%salair%' OR category ILIKE '%payroll%' OR category ILIKE '%paie%' OR category ILIKE '%wage%' OR employee_id IS NOT NULL)
             ), 0) AS operating_expenses
           FROM expenses
           WHERE company_id = $1 AND deleted_at IS NULL AND EXTRACT(YEAR FROM expense_date) = $2
           GROUP BY month`,
          [companyId, targetYear],
        ),
      ]);

    const restCogsByMonthRes = businessType === 'restaurant' || businessType === 'cafe'
      ? { rows: [] }
      : { rows: [] };

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    monthlyBreakdown = Array.from({ length: 12 }, (_, i) => {
      const m = i + 1;
      const sRev = Number(salesByMonthRes.rows.find((r) => r.month === m)?.revenue || 0);
      const cRev = Number(creditByMonthRes.rows.find((r) => r.month === m)?.revenue || 0);
      const clRev = Number(clinicByMonthRes.rows.find((r) => r.month === m)?.revenue || 0);
      const rRev = Number(restByMonthRes.rows.find((r) => r.month === m)?.revenue || 0);
      const mRevenue = sRev + cRev + clRev + rRev;

      const expRow = expByMonthRes.rows.find((r) => r.month === m);
      const mExpenses = Number(expRow?.total_expenses || 0);
      const mSalary = Number(expRow?.salary_expenses || 0);
      const mOperating = Number(expRow?.operating_expenses || 0);

      return {
        month: m,
        monthName: monthNames[i],
        revenue: mRevenue,
        expenses: mExpenses,
        salaryExpenses: mSalary,
        operatingExpenses: mOperating,
        costOfGoodsSold: 0,
        netProfit: mRevenue - mExpenses,
      };
    });
  }

  return {
    // Global Unfiltered Financial Net Profit (All transactions in system)
    global: {
      allRevenue,
      allExpenses,
      globalNetProfit,
      inventoryValue,
    },
    allRevenue,
    allExpenses,
    globalNetProfit,
    inventoryValue,

    // Period specific financials
    period,
    rangeStart,
    rangeEnd,
    revenue,
    inventoryValue,
    expenses: totalExpenses,
    operatingExpenses,
    employeeSalaries,
    costOfGoodsSold: cogsTotal,
    grossProfit,
    netProfit,
    profitMargin,
    salesCount,
    topProducts,
    expensesByCategory,
    employeeSalariesBreakdown,
    revenueBreakdown: {
      sales: coreSalesRevenue,
      creditPayments: creditRev,
      clinicRevenue: clinicRev,
      restaurantRevenue: restaurantRev,
      totalRevenue: revenue,
    },
    expensesBreakdown: {
      operatingExpenses,
      employeeSalaries,
      costOfGoodsSold: businessType === 'restaurant' ? cogsTotal : 0,
      totalExpenses,
      byCategory: expensesByCategory,
      byEmployee: employeeSalariesBreakdown,
    },
    activitySummary,
    recentTransactions,
    monthlyBreakdown,
  };
}

module.exports = {
  resolveRange,
  calculateFinancials,
};

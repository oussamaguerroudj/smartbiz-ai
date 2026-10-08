const { query } = require('../../config/db');

/**
 * Enterprise / Company vertical (business-specialization brief Ch. 19).
 *
 * Only ONE new table backs this vertical (`enterprise_projects`,
 * migration 021)  -  Clients, Employees/Salaries, Suppliers, Invoices,
 * Payments and Expenses are all CORE data reused as-is (Ch. 21).
 *
 * Every function takes companyId as its first argument and binds it
 * directly into `WHERE company_id = $1`, same tenant-isolation rule as
 * every other module (SPECIALIZED_MODULES.md §4).
 */

const OPEN_STATUSES = ['planned', 'active', 'on_hold'];

// ---------------------------------------------------------------------
// Financial building blocks (CORE tables)
// ---------------------------------------------------------------------

/** Invoiced sales revenue for a date range  -  the same `SUM(total)` over
 * `sales.sold_at` the CORE dashboard uses. Credit payments are added
 * on top in the service, exactly like the CORE dashboard does. */
async function salesRevenueForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT COALESCE(SUM(total), 0) AS revenue, COUNT(*)::int AS count
     FROM sales
     WHERE company_id = $1 AND sold_at::date BETWEEN $2::date AND $3::date`,
    [companyId, rangeStart, rangeEnd],
  );
  return {
    revenue: Number(result.rows[0].revenue),
    invoicesIssued: result.rows[0].count,
  };
}

/** Ch. 19's "Outstanding invoices": every invoice still `unpaid`, with
 * the amount taken from its sale's total (invoices are 1:1 with sales
 *  -  migration 008). Oldest first, since those are the ones to chase. */
async function unpaidInvoices(companyId, limit = 5) {
  const [totalResult, listResult] = await Promise.all([
    query(
      `SELECT COALESCE(SUM(s.total), 0) AS total, COUNT(*)::int AS count
       FROM invoices i
       JOIN sales s ON s.id = i.sale_id AND s.company_id = i.company_id
       WHERE i.company_id = $1 AND i.status = 'unpaid'`,
      [companyId],
    ),
    query(
      `SELECT i.id, i.invoice_number, s.total, s.sold_at, c.name AS customer_name
       FROM invoices i
       JOIN sales s ON s.id = i.sale_id AND s.company_id = i.company_id
       LEFT JOIN customers c ON c.id = s.customer_id AND c.company_id = i.company_id
       WHERE i.company_id = $1 AND i.status = 'unpaid'
       ORDER BY s.sold_at ASC
       LIMIT $2`,
      [companyId, limit],
    ),
  ]);
  return {
    totalAmount: Number(totalResult.rows[0].total),
    count: totalResult.rows[0].count,
    list: listResult.rows,
  };
}

/** Total credit balance still owed by clients (`customers.balance_due`,
 * kept authoritative by credit.service.js). Separate from unpaid
 * invoices: credit sales live in their own tables, not `invoices`. */
async function clientBalances(companyId) {
  const result = await query(
    `SELECT COALESCE(SUM(balance_due), 0) AS total, COUNT(*)::int AS count
     FROM customers
     WHERE company_id = $1 AND deleted_at IS NULL AND balance_due > 0`,
    [companyId],
  );
  return { total: Number(result.rows[0].total), count: result.rows[0].count };
}

async function clientsCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM customers WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return result.rows[0].count;
}

async function employeesCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM employees WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return result.rows[0].count;
}

async function suppliersCount(companyId) {
  const result = await query(
    `SELECT COUNT(*)::int AS count FROM suppliers WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return result.rows[0].count;
}

// ---------------------------------------------------------------------
// Projects (the one new table)
// ---------------------------------------------------------------------

/** Count of projects per status, plus how many open ones are past
 * their due date. */
async function projectSummary(companyId) {
  const [byStatus, overdue] = await Promise.all([
    query(
      `SELECT status, COUNT(*)::int AS count
       FROM enterprise_projects
       WHERE company_id = $1 AND deleted_at IS NULL
       GROUP BY status`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count
       FROM enterprise_projects
       WHERE company_id = $1 AND deleted_at IS NULL
         AND status = ANY($2::enterprise_project_status_enum[])
         AND due_date IS NOT NULL AND due_date < CURRENT_DATE`,
      [companyId, OPEN_STATUSES],
    ),
  ]);

  const counts = { planned: 0, active: 0, on_hold: 0, completed: 0, cancelled: 0 };
  for (const row of byStatus.rows) counts[row.status] = row.count;

  return {
    planned: counts.planned,
    active: counts.active,
    onHold: counts.on_hold,
    completed: counts.completed,
    cancelled: counts.cancelled,
    overdue: overdue.rows[0].count,
    total: Object.values(counts).reduce((a, b) => a + b, 0),
  };
}

const PROJECT_SELECT = `
  SELECT p.id, p.name, p.description, p.status, p.budget,
         to_char(p.start_date, 'YYYY-MM-DD') AS start_date,
         to_char(p.due_date, 'YYYY-MM-DD') AS due_date,
         p.completed_at, p.customer_id, p.created_at,
         c.name AS customer_name,
         (p.status = ANY($2::enterprise_project_status_enum[])
            AND p.due_date IS NOT NULL AND p.due_date < CURRENT_DATE) AS is_overdue
  FROM enterprise_projects p
  LEFT JOIN customers c ON c.id = p.customer_id AND c.company_id = p.company_id
`;

/** Open projects (planned/active/on hold), most urgent due date first  - 
 * what the dashboard's Projects card shows. */
async function openProjects(companyId, limit = 5) {
  const result = await query(
    `${PROJECT_SELECT}
     WHERE p.company_id = $1 AND p.deleted_at IS NULL
       AND p.status = ANY($2::enterprise_project_status_enum[])
     ORDER BY p.due_date ASC NULLS LAST, p.created_at DESC
     LIMIT $3`,
    [companyId, OPEN_STATUSES, limit],
  );
  return result.rows;
}

async function listProjects(companyId, status) {
  const params = [companyId, OPEN_STATUSES];
  let where = 'p.company_id = $1 AND p.deleted_at IS NULL';
  if (status) {
    params.push(status);
    where += ` AND p.status = $${params.length}`;
  }
  const result = await query(
    `${PROJECT_SELECT}
     WHERE ${where}
     ORDER BY (p.status = ANY($2::enterprise_project_status_enum[])) DESC,
              p.due_date ASC NULLS LAST, p.created_at DESC`,
    params,
  );
  return result.rows;
}

async function customerExists(companyId, customerId) {
  const result = await query(
    `SELECT 1 FROM customers WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, customerId],
  );
  return result.rowCount > 0;
}

async function createProject(companyId, { customerId, name, description, status, budget, startDate, dueDate }) {
  const finalStatus = status || 'planned';
  const result = await query(
    `INSERT INTO enterprise_projects
       (company_id, customer_id, name, description, status, budget, start_date, due_date, completed_at)
     VALUES ($1, $2, $3, $4, $5::enterprise_project_status_enum, $6, $7, $8,
             CASE WHEN $9::boolean THEN now() ELSE NULL END)
     RETURNING id`,
    [
      companyId,
      customerId || null,
      name,
      description || null,
      finalStatus,
      budget ?? null,
      startDate || null,
      dueDate || null,
      finalStatus === 'completed',
    ],
  );
  return findProject(companyId, result.rows[0].id);
}

async function findProject(companyId, id) {
  const result = await query(
    `${PROJECT_SELECT}
     WHERE p.company_id = $1 AND p.id = $3 AND p.deleted_at IS NULL`,
    [companyId, OPEN_STATUSES, id],
  );
  return result.rows[0] || null;
}

async function updateProjectStatus(companyId, id, status) {
  const result = await query(
    `UPDATE enterprise_projects
     SET status = $3::enterprise_project_status_enum,
         completed_at = CASE WHEN $4::boolean THEN now() ELSE NULL END
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING id`,
    [companyId, id, status, status === 'completed'],
  );
  if (!result.rows[0]) return null;
  return findProject(companyId, id);
}

module.exports = {
  salesRevenueForRange,
  unpaidInvoices,
  clientBalances,
  clientsCount,
  employeesCount,
  suppliersCount,
  projectSummary,
  openProjects,
  listProjects,
  customerExists,
  createProject,
  findProject,
  updateProjectStatus,
};

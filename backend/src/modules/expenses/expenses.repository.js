const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function verifyEmployeeBelongsToCompany(companyId, employeeId) {
  if (!employeeId) return;
  const res = await query(
    'SELECT id FROM employees WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
    [companyId, employeeId],
  );
  if (res.rows.length === 0) {
    throw ApiError.badRequest('Employee not found for this company', 'VALIDATION_ERROR');
  }
}

async function findAll(companyId) {
  const result = await query(
    `SELECT e.*, emp.name AS employee_name
     FROM expenses e
     LEFT JOIN employees emp ON emp.id = e.employee_id AND emp.company_id = e.company_id
     WHERE e.company_id = $1 AND e.deleted_at IS NULL
     ORDER BY e.expense_date DESC, e.created_at DESC`,
    [companyId],
  );
  return result.rows;
}

async function findByClientId(companyId, clientId) {
  if (!clientId) return null;
  const result = await query(
    `SELECT e.*, emp.name AS employee_name
     FROM expenses e
     LEFT JOIN employees emp ON emp.id = e.employee_id AND emp.company_id = e.company_id
     WHERE e.company_id = $1 AND e.client_id = $2 AND e.deleted_at IS NULL`,
    [companyId, clientId],
  );
  return result.rows[0] || null;
}

async function create(
  companyId,
  {
    category,
    description,
    amount,
    expenseDate,
    periodType,
    periodStart,
    periodEnd,
    employeeId,
    salaryPeriod,
    duration,
    clientId,
  },
) {
  await verifyEmployeeBelongsToCompany(companyId, employeeId);
  const finalExpenseDate = expenseDate || periodStart || new Date().toISOString().slice(0, 10);
  const result = await query(
    `INSERT INTO expenses (
       company_id, category, description, amount, expense_date,
       period_type, period_start, period_end, employee_id, salary_period, duration, client_id
     )
     VALUES ($1, $2, $3, $4, $5::date, $6, $7::date, $8::date, $9, $10, $11, $12)
     RETURNING *`,
    [
      companyId,
      category,
      description || null,
      amount,
      finalExpenseDate,
      periodType || 'one_time',
      periodStart || finalExpenseDate,
      periodEnd || finalExpenseDate,
      employeeId || null,
      salaryPeriod || null,
      duration || null,
      clientId || null,
    ],
  );
  return result.rows[0];
}

async function findById(companyId, id) {
  const result = await query(
    `SELECT e.*, emp.name AS employee_name
     FROM expenses e
     LEFT JOIN employees emp ON emp.id = e.employee_id AND emp.company_id = e.company_id
     WHERE e.company_id = $1 AND e.id = $2 AND e.deleted_at IS NULL`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function checkDuplicateSalary(companyId, employeeId, salaryPeriod, excludeId = null) {
  if (!employeeId || !salaryPeriod) return null;
  const result = await query(
    `SELECT id, amount, expense_date, salary_period
     FROM expenses
     WHERE company_id = $1
       AND employee_id = $2
       AND salary_period = $3
       AND deleted_at IS NULL
       AND ($4::uuid IS NULL OR id != $4)
     LIMIT 1`,
    [companyId, employeeId, salaryPeriod, excludeId || null],
  );
  return result.rows[0] || null;
}

async function update(
  companyId,
  id,
  {
    category,
    description,
    amount,
    expenseDate,
    periodType,
    periodStart,
    periodEnd,
    employeeId,
    salaryPeriod,
    duration,
  },
) {
  await verifyEmployeeBelongsToCompany(companyId, employeeId);
  const result = await query(
    `UPDATE expenses
     SET category = COALESCE($3, category),
         description = COALESCE($4, description),
         amount = COALESCE($5, amount),
         expense_date = COALESCE($6::date, expense_date),
         period_type = COALESCE($7::expense_period_type_enum, period_type),
         period_start = COALESCE($8::date, period_start),
         period_end = COALESCE($9::date, period_end),
         employee_id = COALESCE($10, employee_id),
         salary_period = COALESCE($11, salary_period),
         duration = COALESCE($12, duration),
         updated_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      id,
      category,
      description,
      amount,
      expenseDate,
      periodType,
      periodStart,
      periodEnd,
      employeeId,
      salaryPeriod,
      duration,
    ],
  );
  return result.rows[0] || null;
}

async function softDelete(companyId, id) {
  const result = await query(
    `UPDATE expenses SET deleted_at = now() WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL RETURNING id`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

/**
 * Total of ACTUAL expenses stored in the database within [rangeStart, rangeEnd].
 * NEVER estimates, divides, or prorates across days/weeks.
 */
async function totalForRange(companyId, rangeStart, rangeEnd, { excludeSalaryCategories = false, onlySalaryCategories = false } = {}) {
  let filter = '';
  if (excludeSalaryCategories) {
    filter = ` AND NOT (category ILIKE '%salary%' OR category ILIKE '%salair%' OR category ILIKE '%payroll%' OR category ILIKE '%paie%' OR category ILIKE '%wage%' OR employee_id IS NOT NULL)`;
  } else if (onlySalaryCategories) {
    filter = ` AND (category ILIKE '%salary%' OR category ILIKE '%salair%' OR category ILIKE '%payroll%' OR category ILIKE '%paie%' OR category ILIKE '%wage%' OR employee_id IS NOT NULL)`;
  }

  const result = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total
     FROM expenses
     WHERE company_id = $1
       AND deleted_at IS NULL
       AND expense_date BETWEEN $2::date AND $3::date${filter}`,
    [companyId, rangeStart, rangeEnd],
  );
  return Number(result.rows[0].total);
}

async function salariesBreakdownForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT
       e.id,
       e.employee_id,
       COALESCE(emp.name, e.description, 'Employee') AS name,
       emp.position,
       COALESCE(emp.base_salary, e.amount) AS "baseSalary",
       e.amount AS "periodSalary",
       e.expense_date AS "paymentDate",
       e.salary_period AS "salaryPeriod",
       e.duration
     FROM expenses e
     LEFT JOIN employees emp ON emp.id = e.employee_id AND emp.company_id = e.company_id
     WHERE e.company_id = $1
       AND e.deleted_at IS NULL
       AND (e.category ILIKE '%salary%' OR e.category ILIKE '%salair%' OR e.category ILIKE '%payroll%' OR e.category ILIKE '%paie%' OR e.category ILIKE '%wage%' OR e.employee_id IS NOT NULL)
       AND e.expense_date BETWEEN $2::date AND $3::date
     ORDER BY e.expense_date DESC`,
    [companyId, rangeStart, rangeEnd],
  );
  return result.rows.map((r) => ({
    id: r.employee_id || r.id,
    name: r.name,
    position: r.position || null,
    baseSalary: Number(r.baseSalary || 0),
    periodSalary: Number(r.periodSalary || 0),
    paymentDate: r.paymentDate,
    salaryPeriod: r.salaryPeriod,
    duration: r.duration,
  }));
}

async function monthTotal(companyId) {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0));
  const toDateStr = (d) => d.toISOString().slice(0, 10);

  return totalForRange(companyId, toDateStr(start), toDateStr(end));
}

async function globalTotal(companyId) {
  const result = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total
     FROM expenses
     WHERE company_id = $1 AND deleted_at IS NULL`,
    [companyId],
  );
  return Number(result.rows[0].total);
}

module.exports = {
  findAll,
  findById,
  findByClientId,
  create,
  update,
  softDelete,
  checkDuplicateSalary,
  totalForRange,
  salariesBreakdownForRange,
  monthTotal,
  globalTotal,
};

const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT * FROM employees WHERE company_id = $1 AND deleted_at IS NULL ORDER BY name ASC`,
    [companyId],
  );
  return result.rows;
}

async function findById(companyId, id) {
  const result = await query(
    `SELECT * FROM employees WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function create(companyId, { name, position, phone, baseSalary }) {
  const result = await query(
    `INSERT INTO employees (company_id, name, position, phone, base_salary)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [companyId, name, position || null, phone || null, baseSalary],
  );
  return result.rows[0];
}

async function markAttendance(companyId, employeeId, workDate, status) {
  // ON CONFLICT handles re-marking the same day (matches the DB's
  // UNIQUE (employee_id, work_date) from Phase 3 migration 003).
  const result = await query(
    `INSERT INTO attendance_records (company_id, employee_id, work_date, status)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (employee_id, work_date) DO UPDATE SET status = EXCLUDED.status
     RETURNING *`,
    [companyId, employeeId, workDate, status],
  );
  return result.rows[0];
}

async function attendanceSummary(companyId, employeeId) {
  const result = await query(
    `SELECT status, COUNT(*)::int AS count FROM attendance_records
     WHERE company_id = $1 AND employee_id = $2
     GROUP BY status`,
    [companyId, employeeId],
  );
  const summary = { present: 0, absent: 0, late: 0 };
  for (const row of result.rows) summary[row.status] = row.count;
  return summary;
}

async function addSalaryAdjustment(companyId, employeeId, { type, amount, periodMonth, note }) {
  const result = await query(
    `INSERT INTO salary_adjustments (company_id, employee_id, type, amount, period_month, note)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [companyId, employeeId, type, amount, periodMonth, note || null],
  );
  return result.rows[0];
}

async function netSalary(companyId, employeeId, periodMonth) {
  const empResult = await query(
    'SELECT base_salary FROM employees WHERE company_id = $1 AND id = $2',
    [companyId, employeeId],
  );
  if (!empResult.rows[0]) return null;
  const base = Number(empResult.rows[0].base_salary);

  const adjResult = await query(
    `SELECT type, COALESCE(SUM(amount), 0) AS total FROM salary_adjustments
     WHERE company_id = $1 AND employee_id = $2 AND period_month = $3
     GROUP BY type`,
    [companyId, employeeId, periodMonth],
  );
  let bonuses = 0;
  let deductions = 0;
  for (const row of adjResult.rows) {
    if (row.type === 'bonus') bonuses = Number(row.total);
    if (row.type === 'deduction') deductions = Number(row.total);
  }
  return { base, bonuses, deductions, net: base + bonuses - deductions };
}

module.exports = {
  findAll,
  findById,
  create,
  markAttendance,
  attendanceSummary,
  addSalaryAdjustment,
  netSalary,
};

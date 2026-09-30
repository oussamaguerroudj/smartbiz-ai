const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT *
     FROM employees
     WHERE company_id = $1
       AND deleted_at IS NULL
     ORDER BY name ASC`,
    [companyId],
  );

  return result.rows;
}

async function findById(companyId, id) {
  const result = await query(
    `SELECT *
     FROM employees
     WHERE company_id = $1
       AND id = $2
       AND deleted_at IS NULL`,
    [companyId, id],
  );

  return result.rows[0] || null;
}

async function create(
  companyId,
  {
    name,
    position,
    phone,
    baseSalary,
  },
) {
  const result = await query(
    `INSERT INTO employees
       (company_id, name, position, phone, base_salary)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [
      companyId,
      name,
      position || null,
      phone || null,
      baseSalary,
    ],
  );

  return result.rows[0];
}

async function update(
  companyId,
  id,
  {
    name,
    position,
    phone,
    baseSalary,
  },
) {
  const result = await query(
    `UPDATE employees
     SET name = COALESCE($3, name),
         position = COALESCE($4, position),
         phone = COALESCE($5, phone),
         base_salary = COALESCE($6, base_salary),
         updated_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      id,
      name,
      position,
      phone,
      baseSalary,
    ],
  );

  return result.rows[0] || null;
}

async function softDelete(companyId, id) {
  const result = await query(
    `UPDATE employees
     SET deleted_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING id`,
    [companyId, id],
  );

  return result.rows[0] || null;
}

async function markAttendance(
  companyId,
  employeeId,
  workDate,
  status,
) {
  const result = await query(
    `INSERT INTO attendance_records
       (company_id, employee_id, work_date, status)
     SELECT $1, e.id, $3, $4
     FROM employees e
     WHERE e.company_id = $1
       AND e.id = $2
       AND e.deleted_at IS NULL
     ON CONFLICT (employee_id, work_date)
     DO UPDATE SET status = EXCLUDED.status
     RETURNING *`,
    [
      companyId,
      employeeId,
      workDate,
      status,
    ],
  );

  return result.rows[0] || null;
}

async function attendanceSummary(
  companyId,
  employeeId,
) {
  const result = await query(
    `SELECT status, COUNT(*)::int AS count
     FROM attendance_records
     WHERE company_id = $1
       AND employee_id = $2
     GROUP BY status`,
    [
      companyId,
      employeeId,
    ],
  );

  const summary = {
    present: 0,
    absent: 0,
    late: 0,
  };

  for (const row of result.rows) {
    if (Object.prototype.hasOwnProperty.call(summary, row.status)) {
      summary[row.status] = row.count;
    }
  }

  return summary;
}

async function addSalaryAdjustment(
  companyId,
  employeeId,
  {
    type,
    amount,
    periodMonth,
    note,
  },
) {
  const result = await query(
    `INSERT INTO salary_adjustments
       (company_id, employee_id, type, amount, period_month, note)
     SELECT $1, e.id, $3, $4, $5, $6
     FROM employees e
     WHERE e.company_id = $1
       AND e.id = $2
       AND e.deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      employeeId,
      type,
      amount,
      periodMonth,
      note || null,
    ],
  );

  return result.rows[0] || null;
}

async function netSalary(
  companyId,
  employeeId,
  periodMonth,
) {
  const empResult = await query(
    `SELECT base_salary
     FROM employees
     WHERE company_id = $1
       AND id = $2
       AND deleted_at IS NULL`,
    [
      companyId,
      employeeId,
    ],
  );

  if (!empResult.rows[0]) {
    return null;
  }

  const base = Number(empResult.rows[0].base_salary);

  const adjResult = await query(
    `SELECT type,
            COALESCE(SUM(amount), 0) AS total
     FROM salary_adjustments
     WHERE company_id = $1
       AND employee_id = $2
       AND period_month = $3
     GROUP BY type`,
    [
      companyId,
      employeeId,
      periodMonth,
    ],
  );

  let bonuses = 0;
  let deductions = 0;

  for (const row of adjResult.rows) {
    if (row.type === 'bonus') {
      bonuses = Number(row.total);
    }

    if (row.type === 'deduction') {
      deductions = Number(row.total);
    }
  }

  return {
    base,
    bonuses,
    deductions,
    net: base + bonuses - deductions,
  };
}

/**
 * Total employee salary cost from ACTUAL recorded salary transactions within [rangeStart, rangeEnd].
 * NEVER estimates, divides, or prorates salary across days or weeks.
 */
async function totalSalaryCostForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total
     FROM expenses
     WHERE company_id = $1
       AND deleted_at IS NULL
       AND (category ILIKE '%salary%' OR category ILIKE '%salair%' OR category ILIKE '%payroll%' OR category ILIKE '%paie%' OR category ILIKE '%wage%' OR employee_id IS NOT NULL)
       AND expense_date BETWEEN $2::date AND $3::date`,
    [companyId, rangeStart, rangeEnd],
  );

  return Number(result.rows[0].total);
}

async function findSalaryPayments(companyId, employeeId) {
  const result = await query(
    `SELECT *
     FROM expenses
     WHERE company_id = $1
       AND employee_id = $2
       AND deleted_at IS NULL
     ORDER BY expense_date DESC, created_at DESC`,
    [companyId, employeeId],
  );
  return result.rows;
}

module.exports = {
  findAll,
  findById,
  create,
  update,
  softDelete,
  markAttendance,
  attendanceSummary,
  addSalaryAdjustment,
  netSalary,
  totalSalaryCostForRange,
  findSalaryPayments,
};
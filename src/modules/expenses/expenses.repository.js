const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT * FROM expenses WHERE company_id = $1 AND deleted_at IS NULL ORDER BY expense_date DESC`,
    [companyId],
  );
  return result.rows;
}

async function create(companyId, { category, description, amount, expenseDate }) {
  const result = await query(
    `INSERT INTO expenses (company_id, category, description, amount, expense_date)
     VALUES ($1, $2, $3, $4, COALESCE($5, CURRENT_DATE)) RETURNING *`,
    [companyId, category, description || null, amount, expenseDate || null],
  );
  return result.rows[0];
}

async function softDelete(companyId, id) {
  const result = await query(
    `UPDATE expenses SET deleted_at = now() WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL RETURNING id`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function monthTotal(companyId) {
  const result = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total FROM expenses
     WHERE company_id = $1 AND deleted_at IS NULL
       AND date_trunc('month', expense_date) = date_trunc('month', CURRENT_DATE)`,
    [companyId],
  );
  return Number(result.rows[0].total);
}

module.exports = { findAll, create, softDelete, monthTotal };

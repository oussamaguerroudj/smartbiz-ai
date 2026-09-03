const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT a.*, c.name AS customer_name FROM appointments a
     LEFT JOIN customers c ON c.id = a.customer_id
     WHERE a.company_id = $1
     ORDER BY a.scheduled_at ASC`,
    [companyId],
  );
  return result.rows;
}

async function create(companyId, { customerId, title, notes, scheduledAt, reminderEnabled }) {
  const result = await query(
    `INSERT INTO appointments (company_id, customer_id, title, notes, scheduled_at, reminder_enabled)
     VALUES ($1, $2, $3, $4, $5, COALESCE($6, true)) RETURNING *`,
    [companyId, customerId || null, title || null, notes || null, scheduledAt, reminderEnabled],
  );
  return result.rows[0];
}

async function updateStatus(companyId, id, status) {
  const result = await query(
    `UPDATE appointments SET status = $3 WHERE company_id = $1 AND id = $2 RETURNING *`,
    [companyId, id, status],
  );
  return result.rows[0] || null;
}

module.exports = { findAll, create, updateStatus };

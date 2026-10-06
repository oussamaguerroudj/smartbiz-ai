const { query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');

async function verifyCustomerAndTable(companyId, { customerId, tableId }) {
  if (customerId) {
    const custRes = await query(
      'SELECT id FROM customers WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
      [companyId, customerId],
    );
    if (custRes.rows.length === 0) {
      throw ApiError.badRequest('Customer not found for this company', 'VALIDATION_ERROR');
    }
  }
  if (tableId) {
    const tblRes = await query(
      'SELECT id FROM restaurant_tables WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
      [companyId, tableId],
    );
    if (tblRes.rows.length === 0) {
      throw ApiError.badRequest('Table not found for this company', 'VALIDATION_ERROR');
    }
  }
}

async function findAll(companyId) {
  const result = await query(
    `SELECT a.*, c.name AS customer_name, rt.name AS table_name
     FROM appointments a
     LEFT JOIN customers c
       ON c.id = a.customer_id
      AND c.company_id = a.company_id
     LEFT JOIN restaurant_tables rt
       ON rt.id = a.table_id
      AND rt.company_id = a.company_id
     WHERE a.company_id = $1
     ORDER BY a.scheduled_at ASC`,
    [companyId],
  );

  return result.rows;
}

async function create(
  companyId,
  {
    customerId,
    title,
    notes,
    scheduledAt,
    reminderEnabled,
    tableId,
  },
) {
  await verifyCustomerAndTable(companyId, { customerId, tableId });

  if (!customerId) {
    const fallback = await query(
      `INSERT INTO appointments
         (company_id, customer_id, title, notes, scheduled_at, reminder_enabled, table_id)
       VALUES ($1, NULL, $2, $3, $4, COALESCE($5, true), $6)
       RETURNING *`,
      [
        companyId,
        title || null,
        notes || null,
        scheduledAt,
        reminderEnabled,
        tableId || null,
      ],
    );

    return fallback.rows[0];
  }

  const result = await query(
    `INSERT INTO appointments
       (company_id, customer_id, title, notes, scheduled_at, reminder_enabled, table_id)
     SELECT
       $1,
       c.id,
       $3,
       $4,
       $5,
       COALESCE($6, true),
       $7
     FROM customers c
     WHERE c.id = $2
       AND c.company_id = $1
       AND c.deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      customerId,
      title || null,
      notes || null,
      scheduledAt,
      reminderEnabled,
      tableId || null,
    ],
  );

  if (!result.rows[0]) {
    throw ApiError.badRequest('Customer not found for this company', 'VALIDATION_ERROR');
  }

  return result.rows[0];
}

async function update(companyId, id, data) {
  await verifyCustomerAndTable(companyId, {
    customerId: data.customerId,
    tableId: data.tableId,
  });

  const fields = ['updated_at = NOW()'];
  const values = [companyId, id];
  let idx = 3;

  if (data.title !== undefined) {
    fields.push(`title = $${idx++}`);
    values.push(data.title || null);
  }
  if (data.notes !== undefined) {
    fields.push(`notes = $${idx++}`);
    values.push(data.notes || null);
  }
  if (data.scheduledAt !== undefined) {
    fields.push(`scheduled_at = $${idx++}`);
    values.push(data.scheduledAt);
  }
  if (data.status !== undefined) {
    fields.push(`status = $${idx++}`);
    values.push(data.status);
  }
  if (data.reminderEnabled !== undefined) {
    fields.push(`reminder_enabled = $${idx++}`);
    values.push(Boolean(data.reminderEnabled));
  }
  if (data.customerId !== undefined) {
    fields.push(`customer_id = $${idx++}`);
    values.push(data.customerId || null);
  }
  if (data.tableId !== undefined) {
    fields.push(`table_id = $${idx++}`);
    values.push(data.tableId || null);
  }

  const result = await query(
    `UPDATE appointments
     SET ${fields.join(', ')}
     WHERE company_id = $1 AND id = $2
     RETURNING *`,
    values,
  );
  return result.rows[0] || null;
}

async function updateStatus(companyId, id, status) {
  const result = await query(
    `UPDATE appointments
     SET status = $3
     WHERE company_id = $1
       AND id = $2
     RETURNING *`,
    [companyId, id, status],
  );

  return result.rows[0] || null;
}

module.exports = {
  findAll,
  create,
  update,
  updateStatus,
};
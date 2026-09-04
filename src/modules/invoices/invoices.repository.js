const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT i.*, s.total, s.sold_at, c.name AS customer_name
     FROM invoices i
     JOIN sales s ON s.id = i.sale_id
     LEFT JOIN customers c ON c.id = s.customer_id
     WHERE i.company_id = $1
     ORDER BY i.created_at DESC`,
    [companyId],
  );
  return result.rows;
}

async function findById(companyId, id) {
  const invoiceResult = await query(
    `SELECT i.*, s.total, s.subtotal, s.discount, s.sold_at, c.name AS customer_name, c.phone AS customer_phone
     FROM invoices i
     JOIN sales s ON s.id = i.sale_id
     LEFT JOIN customers c ON c.id = s.customer_id
     WHERE i.company_id = $1 AND i.id = $2`,
    [companyId, id],
  );
  const invoice = invoiceResult.rows[0];
  if (!invoice) return null;

  const itemsResult = await query(
    `SELECT si.quantity, si.unit_price, si.line_total, p.name AS product_name
     FROM sale_items si JOIN products p ON p.id = si.product_id
     WHERE si.sale_id = $1`,
    [invoice.sale_id],
  );
  return { ...invoice, items: itemsResult.rows };
}

async function updateStatus(companyId, id, status) {
  const result = await query(
    `UPDATE invoices SET status = $3 WHERE company_id = $1 AND id = $2 RETURNING *`,
    [companyId, id, status],
  );
  return result.rows[0] || null;
}

module.exports = { findAll, findById, updateStatus };

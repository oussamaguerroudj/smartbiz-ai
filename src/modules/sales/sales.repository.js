const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT s.*, c.name AS customer_name,
            i.id AS invoice_id, i.invoice_number, i.status AS invoice_status
     FROM sales s
     LEFT JOIN customers c ON c.id = s.customer_id
     LEFT JOIN invoices i ON i.sale_id = s.id
     WHERE s.company_id = $1
     ORDER BY s.sold_at DESC`,
    [companyId],
  );
  return result.rows;
}

async function findById(companyId, id) {
  const saleResult = await query(
    `SELECT s.*, c.name AS customer_name FROM sales s
     LEFT JOIN customers c ON c.id = s.customer_id
     WHERE s.company_id = $1 AND s.id = $2`,
    [companyId, id],
  );
  const sale = saleResult.rows[0];
  if (!sale) return null;

  const itemsResult = await query(
    `SELECT si.*, p.name AS product_name FROM sale_items si
     JOIN products p ON p.id = si.product_id
     WHERE si.sale_id = $1`,
    [id],
  );
  return { ...sale, items: itemsResult.rows };
}

// --- Transactional writes below take `client` (from withTransaction), never the shared pool ---

async function insertSale(client, companyId, { customerId, employeeId, subtotal, discount, total, paymentStatus }) {
  const result = await client.query(
    `INSERT INTO sales (company_id, customer_id, employee_id, subtotal, discount, total, payment_status)
     VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
    [companyId, customerId || null, employeeId || null, subtotal, discount, total, paymentStatus],
  );
  return result.rows[0];
}

async function insertSaleItem(client, saleId, { productId, quantity, unitPrice, unitCost }) {
  const lineTotal = unitPrice * quantity;
  const lineProfit = (unitPrice - unitCost) * quantity;
  const result = await client.query(
    `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, unit_cost, line_total, line_profit)
     VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
    [saleId, productId, quantity, unitPrice, unitCost, lineTotal, lineProfit],
  );
  return result.rows[0];
}

async function insertInvoice(client, companyId, saleId, invoiceNumber, status) {
  const result = await client.query(
    `INSERT INTO invoices (company_id, sale_id, invoice_number, status)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [companyId, saleId, invoiceNumber, status],
  );
  return result.rows[0];
}

/**
 * Generates the next sequential invoice number FOR THIS COMPANY (e.g.
 * INV-1, INV-2...) — must run inside the same transaction as the insert
 * to avoid a race between two concurrent sales picking the same number.
 */
async function nextInvoiceNumber(client, companyId) {
  const result = await client.query(
    `SELECT COUNT(*)::int AS count FROM invoices WHERE company_id = $1`,
    [companyId],
  );
  const nextSeq = result.rows[0].count + 1;
  return `INV-${nextSeq}`;
}

module.exports = {
  findAll,
  findById,
  insertSale,
  insertSaleItem,
  insertInvoice,
  nextInvoiceNumber,
};

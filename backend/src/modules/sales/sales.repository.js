const { query } = require('../../config/db');

async function findAll(companyId) {
  const result = await query(
    `SELECT s.*, c.name AS customer_name,
            i.id AS invoice_id, i.invoice_number, i.status AS invoice_status,
            (SELECT COUNT(*)::int
             FROM sale_items si
             WHERE si.sale_id = s.id) AS item_count
     FROM sales s
     LEFT JOIN customers c
       ON c.id = s.customer_id
      AND c.company_id = s.company_id
     LEFT JOIN invoices i
       ON i.sale_id = s.id
      AND i.company_id = s.company_id
     WHERE s.company_id = $1
     ORDER BY s.sold_at DESC`,
    [companyId],
  );

  return result.rows;
}

async function findById(companyId, id) {
  const saleResult = await query(
    `SELECT s.*, c.name AS customer_name
     FROM sales s
     LEFT JOIN customers c
       ON c.id = s.customer_id
      AND c.company_id = s.company_id
     WHERE s.company_id = $1
       AND s.id = $2`,
    [companyId, id],
  );

  const sale = saleResult.rows[0];

  if (!sale) {
    return null;
  }

  const itemsResult = await query(
    `SELECT si.*, p.name AS product_name
     FROM sale_items si
     JOIN products p
       ON p.id = si.product_id
      AND p.company_id = $1
     WHERE si.sale_id = $2`,
    [companyId, id],
  );

  return {
    ...sale,
    items: itemsResult.rows,
  };
}

// Transactional writes below take `client` from withTransaction.
// They must never use the shared pool.

async function insertSale(
  client,
  companyId,
  {
    customerId,
    employeeId,
    subtotal,
    discount,
    total,
    paymentStatus,
  },
) {
  const result = await client.query(
    `INSERT INTO sales
       (company_id, customer_id, employee_id, subtotal, discount, total, payment_status)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      companyId,
      customerId || null,
      employeeId || null,
      subtotal,
      discount,
      total,
      paymentStatus,
    ],
  );

  return result.rows[0];
}

async function insertSaleItem(
  client,
  saleId,
  {
    productId,
    quantity,
    unitPrice,
    unitCost,
  },
) {
  const lineTotal = unitPrice * quantity;
  const lineProfit = (unitPrice - unitCost) * quantity;

  const result = await client.query(
    `INSERT INTO sale_items
       (sale_id, product_id, quantity, unit_price, unit_cost, line_total, line_profit)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      saleId,
      productId,
      quantity,
      unitPrice,
      unitCost,
      lineTotal,
      lineProfit,
    ],
  );

  return result.rows[0];
}

async function insertInvoice(
  client,
  companyId,
  saleId,
  invoiceNumber,
  status,
) {
  const result = await client.query(
    `INSERT INTO invoices
       (company_id, sale_id, invoice_number, status)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [
      companyId,
      saleId,
      invoiceNumber,
      status,
    ],
  );

  return result.rows[0];
}

/**
 * Generates the next sequential invoice number for a company.
 *
 * The company row is locked FOR UPDATE first. This serializes invoice
 * number generation for the same company and prevents two concurrent
 * transactions from receiving the same number.
 */
async function nextInvoiceNumber(client, companyId) {
  const companyResult = await client.query(
    `SELECT id
     FROM companies
     WHERE id = $1
     FOR UPDATE`,
    [companyId],
  );

  if (!companyResult.rows[0]) {
    throw new Error('Company not found while generating invoice number');
  }

  const result = await client.query(
    `SELECT COUNT(*)::int AS count
     FROM invoices
     WHERE company_id = $1`,
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
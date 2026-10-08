const { query } = require('../../config/db');

// ---------------------------------------------------------------------
// Customers (balance read/update  -  shared with customers.routes.js's
// own `customers` table, kept in sync from here inside transactions)
// ---------------------------------------------------------------------

async function findCustomerForUpdate(client, companyId, customerId) {
  const result = await client.query(
    `SELECT * FROM customers
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     FOR UPDATE`,
    [companyId, customerId],
  );
  return result.rows[0] || null;
}

async function adjustCustomerBalance(client, companyId, customerId, delta) {
  const result = await client.query(
    `UPDATE customers
     SET balance_due = balance_due + $3
     WHERE company_id = $1 AND id = $2
     RETURNING balance_due`,
    [companyId, customerId, delta],
  );
  return Number(result.rows[0].balance_due);
}

// ---------------------------------------------------------------------
// Credit purchases (header + items)
// ---------------------------------------------------------------------

async function insertCreditPurchase(
  client,
  companyId,
  { customerId, subtotal, amountPaidNow, remainingCredit, status, createdBy },
) {
  const result = await client.query(
    `INSERT INTO credit_purchases
       (company_id, customer_id, subtotal, amount_paid_now, remaining_credit, status, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [companyId, customerId, subtotal, amountPaidNow, remainingCredit, status, createdBy || null],
  );
  return result.rows[0];
}

async function insertCreditPurchaseItem(
  client,
  creditPurchaseId,
  { productId, productName, quantity, unitPrice, lineTotal },
) {
  const result = await client.query(
    `INSERT INTO credit_purchase_items
       (credit_purchase_id, product_id, product_name, quantity, unit_price, line_total)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [creditPurchaseId, productId, productName, quantity, unitPrice, lineTotal],
  );
  return result.rows[0];
}

async function findAllCreditPurchases(companyId) {
  const result = await query(
    `SELECT cp.*, c.name AS customer_name, c.phone AS customer_phone
     FROM credit_purchases cp
     JOIN customers c ON c.id = cp.customer_id AND c.company_id = cp.company_id
     WHERE cp.company_id = $1
     ORDER BY cp.created_at DESC`,
    [companyId],
  );
  return result.rows;
}

async function findCreditPurchaseById(companyId, id) {
  const [purchaseResult, itemsResult] = await Promise.all([
    query(
      `SELECT cp.*, c.name AS customer_name, c.phone AS customer_phone
       FROM credit_purchases cp
       JOIN customers c ON c.id = cp.customer_id AND c.company_id = cp.company_id
       WHERE cp.company_id = $1 AND cp.id = $2`,
      [companyId, id],
    ),
    query(
      `SELECT * FROM credit_purchase_items WHERE credit_purchase_id = $1 ORDER BY id`,
      [id],
    ),
  ]);

  const purchase = purchaseResult.rows[0];
  if (!purchase) return null;

  return { ...purchase, items: itemsResult.rows };
}

// ---------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------

async function findPaymentByClientId(companyId, clientId) {
  if (!clientId) return null;
  const result = await query(
    `SELECT * FROM credit_payments WHERE company_id = $1 AND client_id = $2`,
    [companyId, clientId],
  );
  return result.rows[0] || null;
}

async function insertCreditPayment(
  client,
  companyId,
  { customerId, creditPurchaseId, amount, note, createdBy, clientId },
) {
  const result = await client.query(
    `INSERT INTO credit_payments
       (company_id, customer_id, credit_purchase_id, amount, note, created_by, client_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [companyId, customerId, creditPurchaseId || null, amount, note || null, createdBy || null, clientId || null],
  );
  return result.rows[0];
}

/**
 * Total of every credit payment (both the "amount paid now" collected
 * at purchase time and later standalone repayments) received within
 * [rangeStart, rangeEnd]  -  folded into Dashboard/Reports revenue
 * (Ch. 15/20: "عند تسجيل Payment ... يتم تحديث Cash/Revenue"), since
 * this is real cash coming in that the plain `sales` table never sees.
 */
async function totalPaymentsForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total
     FROM credit_payments
     WHERE company_id = $1
       AND paid_at::date BETWEEN $2::date AND $3::date`,
    [companyId, rangeStart, rangeEnd],
  );
  return Number(result.rows[0].total);
}

// ---------------------------------------------------------------------
// Ledger (Transaction History)
// ---------------------------------------------------------------------

async function insertCustomerTransaction(
  client,
  companyId,
  customerId,
  { type, referenceId, amount, balanceAfter, description },
) {
  const result = await client.query(
    `INSERT INTO customer_transactions
       (company_id, customer_id, type, reference_id, amount, balance_after, description)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [companyId, customerId, type, referenceId, amount, balanceAfter, description || null],
  );
  return result.rows[0];
}

async function findCustomerTransactions(companyId, customerId) {
  const result = await query(
    `SELECT * FROM customer_transactions
     WHERE company_id = $1 AND customer_id = $2
     ORDER BY created_at DESC`,
    [companyId, customerId],
  );
  return result.rows;
}

// ---------------------------------------------------------------------
// Summary (Credit page cards  -  Ch. 16)
// ---------------------------------------------------------------------

async function summary(companyId) {
  const [outstandingResult, totalsResult] = await Promise.all([
    query(
      `SELECT COALESCE(SUM(balance_due), 0) AS total
       FROM customers WHERE company_id = $1 AND deleted_at IS NULL`,
      [companyId],
    ),
    query(
      `SELECT
         COALESCE(SUM(subtotal), 0) AS total_credit,
         COALESCE(SUM(amount_paid_now), 0) AS total_paid_at_purchase
       FROM credit_purchases WHERE company_id = $1`,
      [companyId],
    ),
  ]);

  const laterPaymentsResult = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total
     FROM credit_payments
     WHERE company_id = $1 AND credit_purchase_id IS NULL`,
    [companyId],
  );

  const totalCredit = Number(totalsResult.rows[0].total_credit);
  const totalPaid =
    Number(totalsResult.rows[0].total_paid_at_purchase) +
    Number(laterPaymentsResult.rows[0].total);

  return {
    totalOutstanding: Number(outstandingResult.rows[0].total),
    totalCredit,
    totalPaid,
  };
}

module.exports = {
  findCustomerForUpdate,
  adjustCustomerBalance,
  insertCreditPurchase,
  insertCreditPurchaseItem,
  findAllCreditPurchases,
  findCreditPurchaseById,
  insertCreditPayment,
  findPaymentByClientId,
  totalPaymentsForRange,
  insertCustomerTransaction,
  findCustomerTransactions,
  summary,
};

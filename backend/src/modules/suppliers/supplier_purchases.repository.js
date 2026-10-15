const { query } = require('../../config/db');

// --- Purchases ---

async function findPurchaseByClientTransactionId(client, companyId, clientTransactionId) {
  const runner = client || { query };
  const res = await runner.query(
    `SELECT * FROM supplier_purchases
     WHERE company_id = $1 AND client_transaction_id = $2 AND deleted_at IS NULL`,
    [companyId, clientTransactionId],
  );
  return res.rows[0] || null;
}

async function findPurchaseById(client, companyId, purchaseId) {
  const runner = client || { query };
  const res = await runner.query(
    `SELECT * FROM supplier_purchases
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, purchaseId],
  );
  return res.rows[0] || null;
}

async function findPurchaseByIdForUpdate(client, companyId, purchaseId) {
  const res = await client.query(
    `SELECT * FROM supplier_purchases
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     FOR UPDATE`,
    [companyId, purchaseId],
  );
  return res.rows[0] || null;
}

async function insertPurchase(client, companyId, data) {
  const {
    supplierId,
    invoiceNumber,
    purchaseDate,
    totalAmount,
    amountPaid,
    outstandingBalance,
    paymentStatus,
    notes,
    clientTransactionId,
  } = data;

  const res = await client.query(
    `INSERT INTO supplier_purchases
       (company_id, supplier_id, invoice_number, purchase_date, total_amount,
        amount_paid, outstanding_balance, payment_status, notes, client_transaction_id)
     VALUES ($1, $2, $3, COALESCE($4, now()), $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      companyId,
      supplierId,
      invoiceNumber || null,
      purchaseDate || null,
      totalAmount,
      amountPaid,
      outstandingBalance,
      paymentStatus,
      notes || null,
      clientTransactionId || null,
    ],
  );
  return res.rows[0];
}

async function updatePurchasePaymentStatus(client, companyId, purchaseId, amountPaid, outstandingBalance, paymentStatus) {
  const res = await client.query(
    `UPDATE supplier_purchases
     SET amount_paid = $3,
         outstanding_balance = $4,
         payment_status = $5,
         updated_at = now()
     WHERE company_id = $1 AND id = $2
     RETURNING *`,
    [companyId, purchaseId, amountPaid, outstandingBalance, paymentStatus],
  );
  return res.rows[0];
}

async function insertPurchaseItem(client, companyId, purchaseId, item) {
  const {
    productId,
    productName,
    quantity,
    unitCost,
    lineTotal,
  } = item;

  const res = await client.query(
    `INSERT INTO supplier_purchase_items
       (purchase_id, company_id, product_id, product_name, quantity, unit_cost, line_total)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      purchaseId,
      companyId,
      productId || null,
      productName,
      quantity,
      unitCost,
      lineTotal,
    ],
  );
  return res.rows[0];
}

async function findPurchaseItems(purchaseId) {
  const res = await query(
    `SELECT * FROM supplier_purchase_items
     WHERE purchase_id = $1
     ORDER BY created_at ASC`,
    [purchaseId],
  );
  return res.rows;
}

async function findPurchasesBySupplier(companyId, supplierId) {
  const res = await query(
    `SELECT sp.*,
            COALESCE(json_agg(
              json_build_object(
                'id', spi.id,
                'product_id', spi.product_id,
                'product_name', spi.product_name,
                'quantity', spi.quantity,
                'unit_cost', spi.unit_cost,
                'line_total', spi.line_total
              )
            ) FILTER (WHERE spi.id IS NOT NULL), '[]'::json) AS items
     FROM supplier_purchases sp
     LEFT JOIN supplier_purchase_items spi ON spi.purchase_id = sp.id
     WHERE sp.company_id = $1 AND sp.supplier_id = $2 AND sp.deleted_at IS NULL
     GROUP BY sp.id
     ORDER BY sp.purchase_date DESC, sp.created_at DESC`,
    [companyId, supplierId],
  );
  return res.rows;
}

async function findUnpaidPurchasesForUpdate(client, companyId, supplierId) {
  const res = await client.query(
    `SELECT * FROM supplier_purchases
     WHERE company_id = $1 AND supplier_id = $2 AND outstanding_balance > 0 AND deleted_at IS NULL
     ORDER BY purchase_date ASC, created_at ASC
     FOR UPDATE`,
    [companyId, supplierId],
  );
  return res.rows;
}

// --- Payments ---

async function findPaymentByClientId(client, companyId, clientId) {
  const runner = client || { query };
  const res = await runner.query(
    `SELECT * FROM supplier_payments
     WHERE company_id = $1 AND client_id = $2 AND deleted_at IS NULL`,
    [companyId, clientId],
  );
  return res.rows[0] || null;
}

async function insertPayment(client, companyId, data) {
  const {
    supplierId,
    purchaseId,
    amount,
    paymentDate,
    paymentMethod,
    reference,
    notes,
    clientId,
  } = data;

  const res = await client.query(
    `INSERT INTO supplier_payments
       (company_id, supplier_id, purchase_id, amount, payment_date,
        payment_method, reference, notes, client_id)
     VALUES ($1, $2, $3, $4, COALESCE($5, now()), $6, $7, $8, $9)
     RETURNING *`,
    [
      companyId,
      supplierId,
      purchaseId || null,
      amount,
      paymentDate || null,
      paymentMethod || 'cash',
      reference || null,
      notes || null,
      clientId || null,
    ],
  );
  return res.rows[0];
}

async function findPaymentsBySupplier(companyId, supplierId) {
  const res = await query(
    `SELECT sp.*,
            pur.invoice_number AS purchase_invoice_number
     FROM supplier_payments sp
     LEFT JOIN supplier_purchases pur ON pur.id = sp.purchase_id
     WHERE sp.company_id = $1 AND sp.supplier_id = $2 AND sp.deleted_at IS NULL
     ORDER BY sp.payment_date DESC, sp.created_at DESC`,
    [companyId, supplierId],
  );
  return res.rows;
}

// --- Balances & Aggregates ---

async function getSupplierApBalance(companyId, supplierId) {
  const res = await query(
    `SELECT
       COALESCE(SUM(total_amount), 0)::numeric(15,2) AS total_purchases_amount,
       COALESCE(SUM(amount_paid), 0)::numeric(15,2) AS total_purchases_paid,
       COALESCE(SUM(outstanding_balance), 0)::numeric(15,2) AS outstanding_balance,
       COUNT(id)::int AS purchases_count
     FROM supplier_purchases
     WHERE company_id = $1 AND supplier_id = $2 AND deleted_at IS NULL`,
    [companyId, supplierId],
  );

  const paymentCountRes = await query(
    `SELECT COUNT(id)::int AS payments_count,
            COALESCE(SUM(amount), 0)::numeric(15,2) AS total_payments_recorded
     FROM supplier_payments
     WHERE company_id = $1 AND supplier_id = $2 AND deleted_at IS NULL`,
    [companyId, supplierId],
  );

  const purchaseStats = res.rows[0];
  const paymentStats = paymentCountRes.rows[0];

  return {
    total_purchases_amount: parseFloat(purchaseStats.total_purchases_amount) || 0,
    total_purchases_paid: parseFloat(purchaseStats.total_purchases_paid) || 0,
    outstanding_balance: parseFloat(purchaseStats.outstanding_balance) || 0,
    purchases_count: purchaseStats.purchases_count || 0,
    payments_count: paymentStats.payments_count || 0,
    total_payments_recorded: parseFloat(paymentStats.total_payments_recorded) || 0,
  };
}

module.exports = {
  findPurchaseByClientTransactionId,
  findPurchaseById,
  findPurchaseByIdForUpdate,
  insertPurchase,
  updatePurchasePaymentStatus,
  insertPurchaseItem,
  findPurchaseItems,
  findPurchasesBySupplier,
  findUnpaidPurchasesForUpdate,
  findPaymentByClientId,
  insertPayment,
  findPaymentsBySupplier,
  getSupplierApBalance,
};

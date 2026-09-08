const { query } = require('../../config/db');

/**
 * Every function here takes companyId as a REQUIRED first argument and
 * bakes it into the WHERE clause — this is enforcement layer #2 of the
 * multi-tenant architecture (layer #1 is auth.middleware extracting
 * companyId only from the verified JWT). A caller literally cannot
 * fetch/mutate another company's products through this repository.
 */

async function findAll(companyId, { search } = {}) {
  const params = [companyId];
  let sql = 'SELECT * FROM products WHERE company_id = $1 AND deleted_at IS NULL';
  if (search) {
    params.push(`%${search}%`);
    sql += ` AND name ILIKE $${params.length}`;
  }
  sql += ' ORDER BY name ASC';
  const result = await query(sql, params);
  return result.rows;
}

async function findById(companyId, id) {
  const result = await query(
    'SELECT * FROM products WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function create(companyId, data) {
  const result = await query(
    `INSERT INTO products
       (company_id, name, category, barcode, purchase_price, selling_price, quantity, minimum_stock, expiration_date, supplier_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      companyId,
      data.name,
      data.category || null,
      data.barcode || null,
      data.purchasePrice,
      data.sellingPrice,
      data.quantity ?? 0,
      data.minimumStock ?? 5,
      data.expirationDate || null,
      data.supplierId || null,
    ],
  );
  return result.rows[0];
}

async function update(companyId, id, data) {
  const result = await query(
    `UPDATE products SET
       name = COALESCE($3, name),
       category = COALESCE($4, category),
       barcode = COALESCE($5, barcode),
       purchase_price = COALESCE($6, purchase_price),
       selling_price = COALESCE($7, selling_price),
       quantity = COALESCE($8, quantity),
       minimum_stock = COALESCE($9, minimum_stock),
       expiration_date = COALESCE($10, expiration_date)
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      id,
      data.name,
      data.category,
      data.barcode,
      data.purchasePrice,
      data.sellingPrice,
      data.quantity,
      data.minimumStock,
      data.expirationDate,
    ],
  );
  return result.rows[0] || null;
}

async function softDelete(companyId, id) {
  const result = await query(
    `UPDATE products SET deleted_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING id`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

/**
 * Used inside the Sales transaction (sales.service.js). MUST be called
 * with the transaction's own `client`, not the shared pool — otherwise
 * the stock check and the sale insert wouldn't share the same
 * transaction and the ROLLBACK guarantee would break.
 */
async function findManyForUpdate(client, companyId, productIds) {
  const result = await client.query(
    `SELECT * FROM products
     WHERE company_id = $1 AND id = ANY($2::uuid[]) AND deleted_at IS NULL
     FOR UPDATE`, // row-level lock: prevents two concurrent sales from both
    [companyId, productIds], // passing a stock check that only one of them should pass
  );
  return result.rows;
}

async function decrementStock(client, companyId, productId, amount) {
  await client.query(
    `UPDATE products SET quantity = quantity - $3
     WHERE company_id = $1 AND id = $2`,
    [companyId, productId, amount],
  );
}

module.exports = {
  findAll,
  findById,
  create,
  update,
  softDelete,
  findManyForUpdate,
  decrementStock,
};

// backend/tests/integration/migration_032_verification.test.js
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const connectionString = process.env.TEST_DATABASE_URL || 'postgresql://smartbiz:smartbiz_dev_password@localhost:54321/smartbiz_test';

describe('Migration 032 Database Constraints & Safety Verification', () => {
  let client;
  let companyId;
  let saleId;
  let orderId;

  beforeAll(async () => {
    client = new Client({ connectionString });
    await client.connect();

    // 1. Re-run migration to test idempotency
    const migrationSql = fs.readFileSync(
      path.join(__dirname, '../../migrations/032_add_order_id_to_invoices.sql'),
      'utf8',
    );
    await client.query(migrationSql);

    // Setup test tenant and records
    const compRes = await client.query(
      `INSERT INTO companies (name, business_type) VALUES ('Mig032 Test Co', 'restaurant') RETURNING id`,
    );
    companyId = compRes.rows[0].id;

    const saleRes = await client.query(
      `INSERT INTO sales (company_id, total, subtotal, discount) VALUES ($1, 1000, 1000, 0) RETURNING id`,
      [companyId],
    );
    saleId = saleRes.rows[0].id;

    const orderRes = await client.query(
      `INSERT INTO restaurant_orders (company_id, order_number, total_amount) VALUES ($1, 101, 1500) RETURNING id`,
      [companyId],
    );
    orderId = orderRes.rows[0].id;
  });

  afterAll(async () => {
    if (client) {
      if (companyId) {
        await client.query('DELETE FROM companies WHERE id = $1', [companyId]);
      }
      await client.end();
    }
  });

  test('1. Re-running migration 032 is idempotent and produces no errors', async () => {
    const migrationSql = fs.readFileSync(
      path.join(__dirname, '../../migrations/032_add_order_id_to_invoices.sql'),
      'utf8',
    );
    await expect(client.query(migrationSql)).resolves.toBeDefined();
  });

  test('2. Accepts invoice linked to a sale (order_id is NULL)', async () => {
    const res = await client.query(
      `INSERT INTO invoices (company_id, sale_id, invoice_number, status)
       VALUES ($1, $2, 'INV-SALE-1', 'paid') RETURNING *`,
      [companyId, saleId],
    );
    expect(res.rows[0].sale_id).toBe(saleId);
    expect(res.rows[0].order_id).toBeNull();
  });

  test('3. Accepts invoice linked to a restaurant order (sale_id is NULL)', async () => {
    const res = await client.query(
      `INSERT INTO invoices (company_id, order_id, invoice_number, status)
       VALUES ($1, $2, 'INV-RO-1', 'paid') RETURNING *`,
      [companyId, orderId],
    );
    expect(res.rows[0].order_id).toBe(orderId);
    expect(res.rows[0].sale_id).toBeNull();
  });

  test('4. Rejects invoice where BOTH sale_id and order_id are NULL', async () => {
    await expect(
      client.query(
        `INSERT INTO invoices (company_id, sale_id, order_id, invoice_number, status)
         VALUES ($1, NULL, NULL, 'INV-INVALID-1', 'unpaid')`,
        [companyId],
      ),
    ).rejects.toThrow();
  });

  test('5. Rejects invalid combination where BOTH sale_id and order_id are populated', async () => {
    const sale2Res = await client.query(
      `INSERT INTO sales (company_id, total) VALUES ($1, 500) RETURNING id`,
      [companyId],
    );
    const order2Res = await client.query(
      `INSERT INTO restaurant_orders (company_id, order_number, total_amount) VALUES ($1, 102, 500) RETURNING id`,
      [companyId],
    );

    await expect(
      client.query(
        `INSERT INTO invoices (company_id, sale_id, order_id, invoice_number, status)
         VALUES ($1, $2, $3, 'INV-BOTH-1', 'unpaid')`,
        [companyId, sale2Res.rows[0].id, order2Res.rows[0].id],
      ),
    ).rejects.toThrow();
  });

  test('6. Unique constraint enforces exactly one invoice per order', async () => {
    await expect(
      client.query(
        `INSERT INTO invoices (company_id, order_id, invoice_number, status)
         VALUES ($1, $2, 'INV-RO-DUP', 'unpaid')`,
        [companyId, orderId],
      ),
    ).rejects.toThrow(/unique/i);
  });
});

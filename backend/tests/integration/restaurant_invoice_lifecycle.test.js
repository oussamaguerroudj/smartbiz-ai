// backend/tests/integration/restaurant_invoice_lifecycle.test.js
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL || 'postgresql://smartbiz:smartbiz_dev_password@localhost:54321/smartbiz_test';

const { Client } = require('pg');
const restaurantRepo = require('../../src/modules/restaurant/restaurant.repository');
const invoicesRepo = require('../../src/modules/invoices/invoices.repository');

const connectionString = process.env.DATABASE_URL;

describe('Restaurant Order-to-Invoice Lifecycle & Retry Idempotency (Real PostgreSQL)', () => {
  let client;
  let companyId;
  let orderId;

  beforeAll(async () => {
    client = new Client({ connectionString });
    await client.connect();

    const compRes = await client.query(
      `INSERT INTO companies (name, business_type) VALUES ('Resto Invoicing Test Co', 'restaurant') RETURNING id`,
    );
    companyId = compRes.rows[0].id;

    // Create a restaurant order
    const orderRes = await client.query(
      `INSERT INTO restaurant_orders (company_id, order_number, total_amount, amount_paid, payment_status, status, customer_name)
       VALUES ($1, 201, 2500, 2500, 'paid', 'served', 'John Doe')
       RETURNING id`,
      [companyId],
    );
    orderId = orderRes.rows[0].id;

    // Insert order items
    await client.query(
      `INSERT INTO restaurant_order_items (company_id, order_id, item_name, quantity, unit_price, subtotal)
       VALUES ($1, $2, 'Special Pizza', 2, 1000, 2000),
              ($1, $2, 'Soft Drink', 2, 250, 500)`,
      [companyId, orderId],
    );
  });

  afterAll(async () => {
    if (client) {
      if (companyId) {
        await client.query('DELETE FROM companies WHERE id = $1', [companyId]);
      }
      await client.end();
    }
    const { pool } = require('../../src/config/db');
    if (pool) {
      await pool.end();
    }
  });

  test('Completing an order creates exactly 1 invoice with correct total and status', async () => {
    const updatedOrder = await restaurantRepo.updateOrderStatus(companyId, orderId, 'completed');
    expect(updatedOrder.status).toBe('completed');

    const invoices = await invoicesRepo.findAll(companyId);
    expect(invoices).toHaveLength(1);

    const inv = invoices[0];
    expect(inv.order_id).toBe(orderId);
    expect(inv.sale_id).toBeNull();
    expect(Number(inv.total)).toBe(2500);
    expect(inv.status).toBe('paid');
    expect(inv.customer_name).toBe('John Doe');
    expect(inv.invoice_number).toMatch(/^INV-\d+$/);
  });

  test('Retrying the completion request is idempotent and does NOT create a duplicate invoice', async () => {
    // Retry complete
    const retriedOrder = await restaurantRepo.updateOrderStatus(companyId, orderId, 'completed');
    expect(retriedOrder.status).toBe('completed');

    // Verify still exactly 1 invoice
    const invoices = await invoicesRepo.findAll(companyId);
    expect(invoices).toHaveLength(1);

    // Verify findById returns the correct invoice and items
    const invDetails = await invoicesRepo.findById(companyId, invoices[0].id);
    expect(invDetails).not.toBeNull();
    expect(Number(invDetails.total)).toBe(2500);
    expect(invDetails.items).toHaveLength(2);
    expect(invDetails.items[0].product_name).toBe('Special Pizza');
    expect(Number(invDetails.items[0].line_total)).toBe(2000);
    expect(invDetails.items[1].product_name).toBe('Soft Drink');
    expect(Number(invDetails.items[1].line_total)).toBe(500);
  });
});

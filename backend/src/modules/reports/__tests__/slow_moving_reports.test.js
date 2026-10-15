const http = require('http');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const app = require('../../../app');
const { query } = require('../../../config/db');
const env = require('../../../config/env');

describe('Slow-Moving Products Reports API Integration Tests', () => {
  let server;
  let baseUrl;
  let tokenA;
  let tokenB;
  let companyAId;
  let companyBId;

  let prodMatureZeroSales;
  let prodMatureLowSales;
  let prodMatureHighSales;
  let prodNewNoSales;
  let prodOldSalesOnly;

  beforeAll(async () => {
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}/api`;

    // 1. Setup Company A & Owner
    const compARes = await query(
      `INSERT INTO companies (name) VALUES ('Slow Moving Test Co A') RETURNING id`,
    );
    companyAId = compARes.rows[0].id;

    const hash = await bcrypt.hash('TestPass123!', 8);
    const userARes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Owner A', $2, $3, 'owner', true) RETURNING id`,
      [companyAId, `slow_owner_a_${Date.now()}@test.com`, hash],
    );
    tokenA = jwt.sign(
      { sub: userARes.rows[0].id, companyId: companyAId, role: 'owner', emailVerified: true, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );

    // 2. Setup Company B & Owner (for cross-tenant checks)
    const compBRes = await query(
      `INSERT INTO companies (name) VALUES ('Slow Moving Test Co B') RETURNING id`,
    );
    companyBId = compBRes.rows[0].id;

    const userBRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Owner B', $2, $3, 'owner', true) RETURNING id`,
      [companyBId, `slow_owner_b_${Date.now()}@test.com`, hash],
    );
    tokenB = jwt.sign(
      { sub: userBRes.rows[0].id, companyId: companyBId, role: 'owner', emailVerified: true, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );

    // 3. Seed products for Company A:
    // a) Mature product (created 60 days ago) with 0 sales
    const p1 = await query(
      `INSERT INTO products (company_id, name, purchase_price, selling_price, quantity, created_at)
       VALUES ($1, 'Mature Zero Sales Prod', 500, 750, 100, now() - interval '60 days')
       RETURNING id`,
      [companyAId],
    );
    prodMatureZeroSales = p1.rows[0].id;

    // b) Mature product (created 60 days ago) with 1 unit sold recently (low sales <= 2)
    const p2 = await query(
      `INSERT INTO products (company_id, name, purchase_price, selling_price, quantity, created_at)
       VALUES ($1, 'Mature Low Sales Prod', 300, 450, 40, now() - interval '60 days')
       RETURNING id`,
      [companyAId],
    );
    prodMatureLowSales = p2.rows[0].id;

    // c) Mature product (created 60 days ago) with 10 units sold recently (active, > 2)
    const p3 = await query(
      `INSERT INTO products (company_id, name, purchase_price, selling_price, quantity, created_at)
       VALUES ($1, 'Mature High Sales Prod', 100, 150, 50, now() - interval '60 days')
       RETURNING id`,
      [companyAId],
    );
    prodMatureHighSales = p3.rows[0].id;

    // d) NEW product (created 3 days ago) with 0 sales (INSUFFICIENT HISTORY)
    const p4 = await query(
      `INSERT INTO products (company_id, name, purchase_price, selling_price, quantity, created_at)
       VALUES ($1, 'Brand New Prod (3 days old)', 200, 300, 20, now() - interval '3 days')
       RETURNING id`,
      [companyAId],
    );
    prodNewNoSales = p4.rows[0].id;

    // e) Mature product with sales ONLY outside the 30-day window (sold 45 days ago)
    const p5 = await query(
      `INSERT INTO products (company_id, name, purchase_price, selling_price, quantity, created_at)
       VALUES ($1, 'Old Sales Only Prod', 400, 600, 35, now() - interval '60 days')
       RETURNING id`,
      [companyAId],
    );
    prodOldSalesOnly = p5.rows[0].id;

    // 4. Seed sales:
    // Recent sale (5 days ago): 1 unit of prodMatureLowSales, 10 units of prodMatureHighSales
    const s1 = await query(
      `INSERT INTO sales (company_id, total, payment_status, sold_at)
       VALUES ($1, 1950, 'paid', now() - interval '5 days')
       RETURNING id`,
      [companyAId],
    );
    const sale1Id = s1.rows[0].id;
    await query(
      `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, unit_cost, line_total, line_profit)
       VALUES ($1, $2, 1, 450, 300, 450, 150),
              ($1, $3, 10, 150, 100, 1500, 500)`,
      [sale1Id, prodMatureLowSales, prodMatureHighSales],
    );

    // Old sale (45 days ago): 20 units of prodOldSalesOnly
    const s2 = await query(
      `INSERT INTO sales (company_id, total, payment_status, sold_at)
       VALUES ($1, 12000, 'paid', now() - interval '45 days')
       RETURNING id`,
      [companyAId],
    );
    const sale2Id = s2.rows[0].id;
    await query(
      `INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, unit_cost, line_total, line_profit)
       VALUES ($1, $2, 20, 600, 400, 12000, 4000)`,
      [sale2Id, prodOldSalesOnly],
    );
  });

  afterAll(async () => {
    if (companyAId) {
      await query('DELETE FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE company_id = $1)', [companyAId]);
      await query('DELETE FROM sales WHERE company_id = $1', [companyAId]);
      await query('DELETE FROM products WHERE company_id = $1', [companyAId]);
      await query('DELETE FROM users WHERE company_id = $1', [companyAId]);
      await query('DELETE FROM companies WHERE id = $1', [companyAId]);
    }
    if (companyBId) {
      await query('DELETE FROM users WHERE company_id = $1', [companyBId]);
      await query('DELETE FROM companies WHERE id = $1', [companyBId]);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  test('GET /api/reports/slow-moving returns slow-moving products and excludes products with insufficient history', async () => {
    const res = await fetch(`${baseUrl}/reports/slow-moving?days=30&threshold=2`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    const data = body.data;

    expect(data.periodDays).toBe(30);
    expect(data.threshold).toBe(2);

    const ids = data.items.map((i) => i.id);

    // 1. Mature product with zero sales must be included
    expect(ids).toContain(prodMatureZeroSales);
    const zeroItem = data.items.find((i) => i.id === prodMatureZeroSales);
    expect(zeroItem.unitsSold).toBe(0);
    expect(zeroItem.currentStock).toBe(100);
    expect(zeroItem.insufficientHistory).toBe(false);

    // 2. Mature product with 1 sale (<= threshold 2) must be included
    expect(ids).toContain(prodMatureLowSales);
    const lowItem = data.items.find((i) => i.id === prodMatureLowSales);
    expect(lowItem.unitsSold).toBe(1);

    // 3. Product with sales only outside the 30-day window has 0 sales in window -> included
    expect(ids).toContain(prodOldSalesOnly);
    const oldSaleItem = data.items.find((i) => i.id === prodOldSalesOnly);
    expect(oldSaleItem.unitsSold).toBe(0);

    // 4. Mature product with 10 sales (> threshold 2) must NOT be included
    expect(ids).not.toContain(prodMatureHighSales);

    // 5. CRITICAL REQUIREMENT: Brand new product (3 days old) must NOT be classified as slow-moving
    // because available history is insufficient (< 30 days)
    expect(ids).not.toContain(prodNewNoSales);
  });

  test('GET /api/reports/slow-moving?includeInsufficient=true marks recent products with insufficientHistory: true', async () => {
    const res = await fetch(`${baseUrl}/reports/slow-moving?days=30&threshold=2&includeInsufficient=true`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    const ids = body.data.items.map((i) => i.id);

    expect(ids).toContain(prodNewNoSales);
    const newItem = body.data.items.find((i) => i.id === prodNewNoSales);
    expect(newItem.insufficientHistory).toBe(true);
    expect(newItem.daysInInventory).toBeLessThan(30);
  });

  test('GET /api/reports/slow-moving strictly enforces tenant isolation', async () => {
    const res = await fetch(`${baseUrl}/reports/slow-moving?days=30&threshold=2`, {
      headers: { Authorization: `Bearer ${tokenB}` },
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.totalCount).toBe(0);
    expect(body.data.items).toEqual([]);
  });

  test('GET /api/reports/slow-moving rejects invalid query parameters', async () => {
    const invalidDaysRes = await fetch(`${baseUrl}/reports/slow-moving?days=-5`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    expect(invalidDaysRes.status).toBe(400);

    const invalidThresholdRes = await fetch(`${baseUrl}/reports/slow-moving?threshold=invalid`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    expect(invalidThresholdRes.status).toBe(400);
  });
});

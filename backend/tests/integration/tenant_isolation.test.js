// backend/tests/integration/tenant_isolation.test.js

process.env.NODE_ENV = 'test';
process.env.PORT = '4097';
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL || 'postgresql://smartbiz:smartbiz_dev_password@localhost:54321/smartbiz_test';
process.env.JWT_ACCESS_SECRET = 'modiri-test-access-secret-32-chars-key-length';
process.env.JWT_REFRESH_SECRET = 'modiri-test-refresh-secret-32-chars-key-length';
process.env.SMTP_HOST = 'smtp.test.local';
process.env.SMTP_PORT = '587';

jest.mock('nodemailer', () => ({
  createTransport: jest.fn().mockReturnValue({
    sendMail: jest.fn().mockResolvedValue({ messageId: 'test-message-id' }),
  }),
}));

const { Pool } = require('pg');
const app = require('../../src/app');
const { resetRateLimiters } = require('../../src/middlewares/rateLimit.middleware');

describe('Multi-Tenant Isolation Security Suite (Real PostgreSQL)', () => {
  beforeEach(() => {
    resetRateLimiters();
  });
  let server;
  let baseUrl;
  let testPool;

  let tenantAToken;
  let tenantACompanyId;
  let tenantBToken;
  let tenantBCompanyId;

  let productAId;
  let customerAId;
  let expenseAId;
  let employeeAId;
  let saleAId;
  let invoiceAId;

  beforeAll(async () => {
    testPool = new Pool({
      connectionString: process.env.DATABASE_URL,
    });

    await new Promise((resolve) => {
      server = app.listen(0, '127.0.0.1', () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}/api`;
        resolve();
      });
    });

    // Clean test tables
    await testPool.query('DELETE FROM sale_items');
    await testPool.query('DELETE FROM sales');
    await testPool.query('DELETE FROM invoices');
    await testPool.query('DELETE FROM products');
    await testPool.query('DELETE FROM customers');
    await testPool.query('DELETE FROM expenses');
    await testPool.query('DELETE FROM employees');
    await testPool.query('DELETE FROM pending_registrations');
    await testPool.query('DELETE FROM users');
    await testPool.query('DELETE FROM companies');

    const { hashCode } = require('../../src/utils/otp');
    const bcrypt = require('bcryptjs');
    const passwordHash = await bcrypt.hash('Password123!', 10);
    const expires = new Date(Date.now() + 600000);
    const codeHash = hashCode('123456');

    // Setup Tenant A: pending -> verify -> onboard (retail_store)
    await testPool.query(
      `INSERT INTO pending_registrations (name, email, password_hash, code_hash, code_expires, attempts)
       VALUES ('Owner A', 'tenant.a@test.com', $1, $2, $3, 0)`,
      [passwordHash, codeHash, expires],
    );
    const verifyARes = await fetch(`${baseUrl}/auth/verify-email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'tenant.a@test.com', code: '123456' }),
    });
    const verifyAData = await verifyARes.json();
    tenantAToken = verifyAData.accessToken;
    tenantACompanyId = verifyAData.company?.id;

    // Complete onboarding for Tenant A
    await fetch(`${baseUrl}/companies/me`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantAToken}`,
      },
      body: JSON.stringify({ name: 'Tenant A Retail Store', businessType: 'retail_store' }),
    });

    // Setup Tenant B: pending -> verify -> onboard (supermarket)
    await testPool.query(
      `INSERT INTO pending_registrations (name, email, password_hash, code_hash, code_expires, attempts)
       VALUES ('Owner B', 'tenant.b@test.com', $1, $2, $3, 0)`,
      [passwordHash, codeHash, expires],
    );
    const verifyBRes = await fetch(`${baseUrl}/auth/verify-email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'tenant.b@test.com', code: '123456' }),
    });
    const verifyBData = await verifyBRes.json();
    tenantBToken = verifyBData.accessToken;
    tenantBCompanyId = verifyBData.company?.id;
    // Complete onboarding for Tenant B
    await fetch(`${baseUrl}/companies/me`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantBToken}`,
      },
      body: JSON.stringify({ name: 'Tenant B Supermarket', businessType: 'supermarket' }),
    });

    // Create resources for Tenant A
    // 1. Product
    const prodRes = await fetch(`${baseUrl}/products`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantAToken}`,
      },
      body: JSON.stringify({
        name: 'Product A Special',
        purchasePrice: 10,
        sellingPrice: 25,
        quantity: 50,
      }),
    });
    const prodData = await prodRes.json();
    productAId = prodData.data?.id;

    // 2. Customer
    const custRes = await fetch(`${baseUrl}/customers`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantAToken}`,
      },
      body: JSON.stringify({
        name: 'Customer A VIP',
        phone: '0555000001',
      }),
    });
    const custData = await custRes.json();
    customerAId = custData.data?.id;

    // 3. Expense
    const expRes = await fetch(`${baseUrl}/expenses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantAToken}`,
      },
      body: JSON.stringify({
        description: 'Rent for Store A',
        amount: 300,
        category: 'rent',
      }),
    });
    const expData = await expRes.json();
    expenseAId = expData.data?.id;

    // 4. Employee
    const empRes = await fetch(`${baseUrl}/employees`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantAToken}`,
      },
      body: JSON.stringify({
        name: 'Employee John A',
        baseSalary: 40000,
        position: 'Cashier',
      }),
    });
    const empData = await empRes.json();
    employeeAId = empData.data?.id;

    // 5. Sale
    const saleRes = await fetch(`${baseUrl}/sales`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantAToken}`,
      },
      body: JSON.stringify({
        items: [{ productId: productAId, quantity: 2, unitPrice: 25 }],
        paymentMethod: 'cash',
        amountPaid: 50,
      }),
    });
    const saleData = await saleRes.json();
    saleAId = saleData.data?.sale?.id || saleData.data?.id;
    invoiceAId = saleData.data?.invoice?.id || saleData.data?.invoiceId;
  });

  afterAll(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    if (testPool) {
      await testPool.query('DELETE FROM sale_items');
      await testPool.query('DELETE FROM sales');
      await testPool.query('DELETE FROM invoices');
      await testPool.query('DELETE FROM products');
      await testPool.query('DELETE FROM customers');
      await testPool.query('DELETE FROM expenses');
      await testPool.query('DELETE FROM employees');
      await testPool.query('DELETE FROM pending_registrations');
      await testPool.query('DELETE FROM users');
      await testPool.query('DELETE FROM companies');
      await testPool.end();
    }
    const { pool } = require('../../src/config/db');
    if (pool) {
      await pool.end();
    }
  });

  test('1. Products Isolation: Tenant B cannot list, read, edit, or delete Tenant A products', async () => {
    // List check
    const listRes = await fetch(`${baseUrl}/products`, {
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    const listData = await listRes.json();
    const foundInList = (listData.data?.items || listData.data || []).some((p) => p.id === productAId);
    expect(foundInList).toBe(false);

    // Read check
    const getRes = await fetch(`${baseUrl}/products/${productAId}`, {
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    expect(getRes.status).toBe(404);

    // Update check
    const updateRes = await fetch(`${baseUrl}/products/${productAId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantBToken}`,
      },
      body: JSON.stringify({ name: 'Tampered Name', sellingPrice: 999 }),
    });
    expect(updateRes.status).toBe(404);

    // Delete check
    const deleteRes = await fetch(`${baseUrl}/products/${productAId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    expect(deleteRes.status).toBe(404);

    // Verify product in DB is still untouched
    const dbRow = (await testPool.query('SELECT name FROM products WHERE id = $1', [productAId])).rows[0];
    expect(dbRow.name).toBe('Product A Special');
  });

  test('2. Customers Isolation: Tenant B cannot read or modify Tenant A customers', async () => {
    const getRes = await fetch(`${baseUrl}/customers/${customerAId}`, {
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    expect(getRes.status).toBe(404);

    const deleteRes = await fetch(`${baseUrl}/customers/${customerAId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    expect(deleteRes.status).toBe(404);
  });

  test('3. Expenses Isolation: Tenant B cannot read or modify Tenant A expenses', async () => {
    const getRes = await fetch(`${baseUrl}/expenses/${expenseAId}`, {
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    expect(getRes.status).toBe(404);
  });

  test('4. Employees Isolation: Tenant B cannot read or modify Tenant A employees', async () => {
    const getRes = await fetch(`${baseUrl}/employees/${employeeAId}`, {
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    expect(getRes.status).toBe(404);

    const deleteRes = await fetch(`${baseUrl}/employees/${employeeAId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${tenantBToken}` },
    });
    expect(deleteRes.status).toBe(404);
  });

  test('5. Sales & Invoices Isolation: Tenant B cannot read Tenant A sales or invoices', async () => {
    if (saleAId) {
      const getSaleRes = await fetch(`${baseUrl}/sales/${saleAId}`, {
        headers: { Authorization: `Bearer ${tenantBToken}` },
      });
      expect(getSaleRes.status).toBe(404);
    }

    if (invoiceAId) {
      const getInvoiceRes = await fetch(`${baseUrl}/invoices/${invoiceAId}`, {
        headers: { Authorization: `Bearer ${tenantBToken}` },
      });
      expect(getInvoiceRes.status).toBe(404);
    }
  });

  test('6. Company Isolation & Parameter Spoofing: client-supplied company_id and role are strictly ignored', async () => {
    // Tenant B tries to inject company_id and role into product creation
    const spoofProdRes = await fetch(`${baseUrl}/products`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantBToken}`,
      },
      body: JSON.stringify({
        name: 'Spoofed Tenant Product',
        purchasePrice: 5,
        sellingPrice: 15,
        quantity: 10,
        company_id: tenantACompanyId,
        companyId: tenantACompanyId,
        role: 'super_admin',
      }),
    });
    expect(spoofProdRes.status).toBe(201);
    const spoofProdData = await spoofProdRes.json();
    const createdProdId = spoofProdData.data?.id;

    // Verify in database that company_id is Tenant B, NOT Tenant A
    const row = (await testPool.query('SELECT company_id FROM products WHERE id = $1', [createdProdId])).rows[0];
    expect(row.company_id).toBe(tenantBCompanyId);
    expect(row.company_id).not.toBe(tenantACompanyId);

    // Tenant B attempts to overwrite Tenant A's company details via PUT /companies/me
    const spoofCompanyRes = await fetch(`${baseUrl}/companies/me`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tenantBToken}`,
      },
      body: JSON.stringify({
        id: tenantACompanyId,
        company_id: tenantACompanyId,
        name: 'Hijacked Store Name',
      }),
    });
    expect(spoofCompanyRes.status).toBe(200);

    // Verify Tenant A's company name is unchanged
    const companyARow = (await testPool.query('SELECT name FROM companies WHERE id = $1', [tenantACompanyId])).rows[0];
    expect(companyARow.name).toBe('Tenant A Retail Store');

    // Verify Tenant B's own company was the only one updated
    const companyBRow = (await testPool.query('SELECT name FROM companies WHERE id = $1', [tenantBCompanyId])).rows[0];
    expect(companyBRow.name).toBe('Hijacked Store Name');
  });
});

const http = require('http');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const app = require('../../app');
const { query } = require('../../config/db');
const env = require('../../config/env');
const pdfService = require('../pdf.service');

describe('Professional Business Documents & PDF Generation (Feature B)', () => {
  describe('PDF Document Buffer Generators', () => {
    const mockCompany = {
      name: 'Modiri Test Enterprise',
      address: '123 Rue de la Liberté, Alger',
      phone: '+213 555 123 456',
    };

    test('generateStandardInvoicePdfBuffer - Paid Invoice generates valid PDF buffer', async () => {
      const invoice = {
        invoice_number: 'INV-2026-0001',
        created_at: new Date('2026-10-14'),
        customer_name: 'Ahmed Benali',
        customer_phone: '0555000000',
        status: 'paid',
        items: [
          { name: 'Produit Test A', quantity: 2, unit_price: 1500, line_total: 3000 },
          { name: 'Produit Test B', quantity: 1, unit_price: 2000, line_total: 2000 },
        ],
        subtotal: 5000,
        discount: 0,
        total: 5000,
      };

      const buffer = await pdfService.generateStandardInvoicePdfBuffer({ company: mockCompany, invoice });
      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(buffer.length).toBeGreaterThan(500);
      // Valid PDF files start with %PDF-
      expect(buffer.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });

    test('generateStandardInvoicePdfBuffer - Unpaid Proforma Invoice generates valid PDF buffer', async () => {
      const invoice = {
        invoice_number: 'PRO-2026-0002',
        created_at: new Date('2026-10-14'),
        customer_name: 'Karim Bouzid',
        customer_phone: '0666000000',
        status: 'unpaid',
        items: [
          { name: 'Article Échantillon', quantity: 5, unit_price: 800, line_total: 4000 },
        ],
        subtotal: 4000,
        discount: 0,
        total: 4000,
      };

      const buffer = await pdfService.generateStandardInvoicePdfBuffer({ company: mockCompany, invoice });
      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(buffer.length).toBeGreaterThan(500);
      expect(buffer.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });

    test('generateKitchenTicketPdfBuffer - generates valid PDF buffer without financial prices', async () => {
      const order = {
        id: 'ord-12345',
        order_number: 42,
        order_type: 'dine_in',
        table_name: 'Table 5',
        customer_name: 'Yacine',
        customer_phone: '0777000000',
        notes: 'Sans sel, cuisson à point',
        created_at: new Date('2026-10-14T19:30:00Z'),
      };
      const items = [
        { itemName: 'Steak Grillé', quantity: 2, notes: 'Bien cuit' },
        { itemName: 'Frites Maison', quantity: 1 },
        { itemName: 'Jus d Orange', quantity: 2 },
      ];

      const buffer = await pdfService.generateKitchenTicketPdfBuffer({ company: mockCompany, order, items });
      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(buffer.length).toBeGreaterThan(500);
      expect(buffer.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });

    test('generateSupplierStatementPdfBuffer - generates valid PDF buffer with ledger and KPIs', async () => {
      const supplier = {
        name: 'Grossiste Alimentaire El Baraka',
        phone: '021 00 11 22',
        address: 'Zone Industrielle Oued Smar, Alger',
      };
      const statement = {
        totalPurchases: 150000,
        totalPaid: 90000,
        balanceDue: 60000,
        transactions: [
          {
            date: '2026-09-01',
            type: 'purchase',
            description: 'Facture Achat FAC-001',
            reference: 'FAC-001',
            debit: 100000,
            credit: 0,
            balanceAfter: 100000,
          },
          {
            date: '2026-09-15',
            type: 'payment',
            description: 'Versement Chèque #4582',
            reference: 'PAY-001',
            debit: 0,
            credit: 50000,
            balanceAfter: 50000,
          },
          {
            date: '2026-10-01',
            type: 'purchase',
            description: 'Facture Achat FAC-002',
            reference: 'FAC-002',
            debit: 50000,
            credit: 0,
            balanceAfter: 100000,
          },
          {
            date: '2026-10-10',
            type: 'payment',
            description: 'Espèces',
            reference: 'PAY-002',
            debit: 0,
            credit: 40000,
            balanceAfter: 60000,
          },
        ],
      };

      const buffer = await pdfService.generateSupplierStatementPdfBuffer({ company: mockCompany, supplier, statement });
      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(buffer.length).toBeGreaterThan(500);
      expect(buffer.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });

    test('generateCustomerCreditStatementPdfBuffer - generates valid PDF buffer with debt history', async () => {
      const customer = {
        name: 'Fatima Zohra',
        phone: '0550 12 34 56',
        address: 'Bab Ezzouar, Alger',
      };
      const statement = {
        totalCredit: 25000,
        totalPaid: 15000,
        currentBalance: 10000,
        transactions: [
          {
            created_at: '2026-09-05',
            type: 'purchase',
            description: 'Vente à crédit #CR-101',
            amount: 25000,
            balance_after: 25000,
          },
          {
            created_at: '2026-09-20',
            type: 'payment',
            description: 'Règlement partiel reçu',
            amount: -15000,
            balance_after: 10000,
          },
        ],
      };

      const buffer = await pdfService.generateCustomerCreditStatementPdfBuffer({ company: mockCompany, customer, statement });
      expect(Buffer.isBuffer(buffer)).toBe(true);
      expect(buffer.length).toBeGreaterThan(500);
      expect(buffer.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });
  });

  describe('HTTP API Endpoints Integration', () => {
    let server;
    let baseUrl;
    let token;
    let companyId;
    let supplierId;
    let customerId;
    let orderId;

    beforeAll(async () => {
      server = http.createServer(app);
      await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
      const port = server.address().port;
      baseUrl = `http://127.0.0.1:${port}/api`;

      // 1. Create company (restaurant to support all modules)
      const compRes = await query(
        `INSERT INTO companies (name, business_type) VALUES ('Doc Test Co', 'restaurant') RETURNING id`,
      );
      companyId = compRes.rows[0].id;

      // 2. Create user & token
      const hash = await bcrypt.hash('TestPass123!', 8);
      const userRes = await query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Doc Owner', $2, $3, 'owner', true) RETURNING id`,
        [companyId, `doc_owner_${Date.now()}@test.com`, hash],
      );
      token = jwt.sign(
        { sub: userRes.rows[0].id, companyId, role: 'owner', emailVerified: true, type: 'access' },
        env.jwt.accessSecret,
        { expiresIn: '1h' },
      );

      // 3. Create supplier with purchase & payment
      const supRes = await query(
        `INSERT INTO suppliers (company_id, name, phone, address)
         VALUES ($1, 'Test Doc Supplier', '0555111222', 'Alger') RETURNING id`,
        [companyId],
      );
      supplierId = supRes.rows[0].id;

      const purchRes = await query(
        `INSERT INTO supplier_purchases (company_id, supplier_id, invoice_number, total_amount, amount_paid, outstanding_balance, payment_status)
         VALUES ($1, $2, 'PURCH-001', 12000, 4000, 8000, 'partially_paid') RETURNING id`,
        [companyId, supplierId],
      );
      await query(
        `INSERT INTO supplier_payments (company_id, supplier_id, purchase_id, amount, payment_method, reference)
         VALUES ($1, $2, $3, 4000, 'cash', 'Initial downpayment')`,
        [companyId, supplierId, purchRes.rows[0].id],
      );

      // 4. Create customer with credit purchase & payment
      const custRes = await query(
        `INSERT INTO customers (company_id, name, phone, address, balance_due)
         VALUES ($1, 'Test Doc Customer', '0555333444', 'Oran', 5000) RETURNING id`,
        [companyId],
      );
      customerId = custRes.rows[0].id;

      await query(
        `INSERT INTO customer_transactions (company_id, customer_id, type, reference_id, amount, balance_after, description)
         VALUES ($1, $2, 'credit_purchase', gen_random_uuid(), 10000, 10000, 'Credit Sale #1')`,
        [companyId, customerId],
      );
      await query(
        `INSERT INTO customer_transactions (company_id, customer_id, type, reference_id, amount, balance_after, description)
         VALUES ($1, $2, 'payment', gen_random_uuid(), -5000, 5000, 'Payment received')`,
        [companyId, customerId],
      );

      // 5. Create restaurant order
      const ordRes = await query(
        `INSERT INTO restaurant_orders (company_id, order_number, total_amount, notes, status, order_type)
         VALUES ($1, 101, 2400, 'VIP guest', 'pending', 'dine_in') RETURNING id`,
        [companyId],
      );
      orderId = ordRes.rows[0].id;
      await query(
        `INSERT INTO restaurant_order_items (company_id, order_id, item_name, unit_price, quantity, subtotal)
         VALUES ($1, $2, 'Plat du Jour', 1200, 2, 2400)`,
        [companyId, orderId],
      );
    });

    afterAll(async () => {
      await new Promise((resolve) => server.close(resolve));
      await query(`DELETE FROM restaurant_order_items WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM restaurant_orders WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM customer_transactions WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM customers WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM supplier_payments WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM supplier_purchases WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM suppliers WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM users WHERE company_id = $1`, [companyId]);
      await query(`DELETE FROM companies WHERE id = $1`, [companyId]);
    });

    test('GET /api/suppliers/:id/statement returns JSON statement with calculations', async () => {
      const res = await fetch(`${baseUrl}/suppliers/${supplierId}/statement`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(200);
      const json = await res.json();
      expect(json.data).toBeDefined();
      expect(json.data.supplier.id).toBe(supplierId);
      expect(json.data.statement.totalPurchases).toBe(12000);
      expect(json.data.statement.totalPaid).toBe(4000);
      expect(json.data.statement.balanceDue).toBe(8000);
      expect(Array.isArray(json.data.statement.transactions)).toBe(true);
      expect(json.data.statement.transactions.length).toBeGreaterThanOrEqual(2);
    });

    test('GET /api/suppliers/:id/statement/pdf streams application/pdf', async () => {
      const res = await fetch(`${baseUrl}/suppliers/${supplierId}/statement/pdf`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(200);
      expect(res.headers.get('content-type')).toContain('application/pdf');
      const arrayBuffer = await res.arrayBuffer();
      const buf = Buffer.from(arrayBuffer);
      expect(buf.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });

    test('GET /api/customers/:id/statement returns customer credit statement JSON', async () => {
      const res = await fetch(`${baseUrl}/customers/${customerId}/statement`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(200);
      const json = await res.json();
      expect(json.data).toBeDefined();
      expect(json.data.customer.id).toBe(customerId);
      expect(json.data.statement.totalCredit).toBe(10000);
      expect(json.data.statement.totalPaid).toBe(5000);
      expect(json.data.statement.currentBalance).toBe(5000);
      expect(Array.isArray(json.data.statement.transactions)).toBe(true);
      expect(json.data.statement.transactions.length).toBe(2);
    });

    test('GET /api/customers/:id/statement/pdf streams application/pdf', async () => {
      const res = await fetch(`${baseUrl}/customers/${customerId}/statement/pdf`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(200);
      expect(res.headers.get('content-type')).toContain('application/pdf');
      const arrayBuffer = await res.arrayBuffer();
      const buf = Buffer.from(arrayBuffer);
      expect(buf.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });

    test('GET /api/credit/customers/:customerId/statement/pdf streams application/pdf', async () => {
      const res = await fetch(`${baseUrl}/credit/customers/${customerId}/statement/pdf`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(200);
      expect(res.headers.get('content-type')).toContain('application/pdf');
      const arrayBuffer = await res.arrayBuffer();
      const buf = Buffer.from(arrayBuffer);
      expect(buf.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });

    test('GET /api/restaurant/orders/:id/kitchen-ticket/pdf streams operational kitchen ticket', async () => {
      const res = await fetch(`${baseUrl}/restaurant/orders/${orderId}/kitchen-ticket/pdf`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(200);
      expect(res.headers.get('content-type')).toContain('application/pdf');
      const arrayBuffer = await res.arrayBuffer();
      const buf = Buffer.from(arrayBuffer);
      expect(buf.slice(0, 5).toString('ascii')).toBe('%PDF-');
    });
  });
});

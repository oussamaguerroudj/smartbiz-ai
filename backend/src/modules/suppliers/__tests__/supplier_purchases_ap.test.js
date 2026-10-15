const http = require('http');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const app = require('../../../app');
const { query } = require('../../../config/db');
const env = require('../../../config/env');

describe('Supplier Purchases and Accounts-Payable Ledger Integration Tests', () => {
  let server;
  let baseUrl;
  let tokenA;
  let tokenB;
  let companyAId;
  let companyBId;
  let supplierAId;
  let supplierBId;

  beforeAll(async () => {
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}/api`;

    // 1. Setup Company A & Owner
    const compARes = await query(
      `INSERT INTO companies (name) VALUES ('Supplier Test Co A') RETURNING id`,
    );
    companyAId = compARes.rows[0].id;

    const hash = await bcrypt.hash('TestPass123!', 8);
    const userARes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Owner A', $2, $3, 'owner', true) RETURNING id`,
      [companyAId, `supp_owner_a_${Date.now()}@test.com`, hash],
    );
    const userAId = userARes.rows[0].id;
    tokenA = jwt.sign(
      { sub: userAId, companyId: companyAId, role: 'owner', emailVerified: true, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );

    // 2. Setup Company B & Owner (for cross-tenant checks)
    const compBRes = await query(
      `INSERT INTO companies (name) VALUES ('Supplier Test Co B') RETURNING id`,
    );
    companyBId = compBRes.rows[0].id;

    const userBRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Owner B', $2, $3, 'owner', true) RETURNING id`,
      [companyBId, `supp_owner_b_${Date.now()}@test.com`, hash],
    );
    const userBId = userBRes.rows[0].id;
    tokenB = jwt.sign(
      { sub: userBId, companyId: companyBId, role: 'owner', emailVerified: true, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );

    // 3. Create Supplier for Company A
    const suppARes = await query(
      `INSERT INTO suppliers (company_id, name, phone, address)
       VALUES ($1, 'Fournisseur Médical Central', '0555112233', 'Alger Centre') RETURNING id`,
      [companyAId],
    );
    supplierAId = suppARes.rows[0].id;

    // 4. Create Supplier for Company B
    const suppBRes = await query(
      `INSERT INTO suppliers (company_id, name, phone, address)
       VALUES ($1, 'Distributeur Oran', '0555998877', 'Oran Ville') RETURNING id`,
      [companyBId],
    );
    supplierBId = suppBRes.rows[0].id;
  });

  afterAll(async () => {
    if (companyAId) {
      await query('DELETE FROM companies WHERE id = $1', [companyAId]);
    }
    if (companyBId) {
      await query('DELETE FROM companies WHERE id = $1', [companyBId]);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  test('POST /api/suppliers/:id/purchases creates an unpaid purchase invoice and calculates line totals', async () => {
    const res = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-2026-001',
        purchaseDate: '2026-10-14T10:00:00Z',
        items: [
          { productName: 'Gants latex Boîte 100', quantity: 10, unitCost: 450.00 },
          { productName: 'Seringues 5ml', quantity: 20, unitCost: 15.00 },
        ],
        amountPaid: 0,
        notes: 'Commande fournitures urgentes',
      }),
    });

    expect(res.status).toBe(201);
    const body = await res.json();
    const purchase = body.data.purchase;

    expect(purchase.supplier_id).toBe(supplierAId);
    expect(purchase.invoice_number).toBe('INV-2026-001');
    // Total = (10 * 450) + (20 * 15) = 4500 + 300 = 4800.00
    expect(parseFloat(purchase.total_amount)).toBe(4800.00);
    expect(parseFloat(purchase.amount_paid)).toBe(0);
    expect(parseFloat(purchase.outstanding_balance)).toBe(4800.00);
    expect(purchase.payment_status).toBe('unpaid');
    expect(purchase.items).toHaveLength(2);
    expect(parseFloat(purchase.items[0].line_total)).toBe(4500.00);
    expect(parseFloat(purchase.items[1].line_total)).toBe(300.00);
  });

  test('POST /api/suppliers/:id/purchases with partial initial payment creates payment record atomically', async () => {
    const res = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-2026-002',
        items: [
          { productName: 'Alcool 70° 1L', quantity: 5, unitCost: 300.00 },
        ],
        amountPaid: 500.00,
        paymentMethod: 'cash',
      }),
    });

    expect(res.status).toBe(201);
    const body = await res.json();
    const purchase = body.data.purchase;

    // Total = 1500, Paid = 500, Remaining = 1000
    expect(parseFloat(purchase.total_amount)).toBe(1500.00);
    expect(parseFloat(purchase.amount_paid)).toBe(500.00);
    expect(parseFloat(purchase.outstanding_balance)).toBe(1000.00);
    expect(purchase.payment_status).toBe('partially_paid');
    expect(purchase.initial_payment).toBeTruthy();
    expect(parseFloat(purchase.initial_payment.amount)).toBe(500.00);
  });

  test('POST /api/suppliers/:id/purchases with full initial payment sets status to paid', async () => {
    const res = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-2026-003',
        items: [
          { productName: 'Masques chirurgicaux Bte 50', quantity: 2, unitCost: 250.00 },
        ],
        amountPaid: 500.00,
      }),
    });

    expect(res.status).toBe(201);
    const body = await res.json();
    const purchase = body.data.purchase;

    expect(parseFloat(purchase.total_amount)).toBe(500.00);
    expect(parseFloat(purchase.amount_paid)).toBe(500.00);
    expect(parseFloat(purchase.outstanding_balance)).toBe(0);
    expect(purchase.payment_status).toBe('paid');
  });

  test('POST /api/suppliers/:id/purchases rejects initial payment exceeding invoice total', async () => {
    const res = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-2026-OVERPAY',
        items: [
          { productName: 'Bétadine 250ml', quantity: 1, unitCost: 350.00 },
        ],
        amountPaid: 1000.00, // Exceeds 350
      }),
    });

    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.code).toBe('OVERPAYMENT_REJECTED');
  });

  test('POST /api/suppliers/:id/purchases rejects invalid items or negative costs', async () => {
    const res = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-2026-INVALID',
        items: [
          { productName: 'Test Negative Cost', quantity: 1, unitCost: -50.00 },
        ],
      }),
    });

    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.code).toBe('VALIDATION_ERROR');
  });

  test('POST /api/suppliers/:id/purchases is idempotent on duplicate clientTransactionId', async () => {
    const clientTx = `tx_purch_${Date.now()}`;
    const payload = {
      invoiceNumber: 'INV-IDEMPOTENT',
      items: [
        { productName: 'Pansements stériles', quantity: 4, unitCost: 100.00 },
      ],
      amountPaid: 0,
      clientTransactionId: clientTx,
    };

    // First call
    const res1 = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify(payload),
    });
    expect(res1.status).toBe(201);
    const body1 = await res1.json();
    const purchase1Id = body1.data.purchase.id;

    // Second call with identical clientTransactionId
    const res2 = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify(payload),
    });
    expect(res2.status).toBe(201);
    const body2 = await res2.json();
    expect(body2.data.purchase.id).toBe(purchase1Id);
    expect(body2.data.idempotent).toBe(true);

    // Verify only 1 record exists in DB
    const countRes = await query(
      'SELECT COUNT(*)::int AS cnt FROM supplier_purchases WHERE company_id = $1 AND client_transaction_id = $2',
      [companyAId, clientTx],
    );
    expect(countRes.rows[0].cnt).toBe(1);
  });

  test('POST /api/suppliers/:id/payments records payment against a specific invoice and updates balance', async () => {
    // 1. Create a 2000.00 unpaid purchase
    const purchRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-PAY-TEST',
        items: [{ productName: 'Thermomètres Digitaux', quantity: 2, unitCost: 1000.00 }],
        amountPaid: 0,
      }),
    });
    const purchData = await purchRes.json();
    const purchaseId = purchData.data.purchase.id;

    // 2. Make partial payment of 1200.00
    const payRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/payments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        purchaseId,
        amount: 1200.00,
        paymentMethod: 'bank_transfer',
        reference: 'VIR-998877',
      }),
    });
    expect(payRes.status).toBe(201);
    const payBody = await payRes.json();

    expect(payBody.data.purchase.amount_paid).toBe(1200.00);
    expect(payBody.data.purchase.outstanding_balance).toBe(800.00);
    expect(payBody.data.purchase.payment_status).toBe('partially_paid');

    // 3. Make remaining payment of 800.00
    const payRes2 = await fetch(`${baseUrl}/suppliers/${supplierAId}/payments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        purchaseId,
        amount: 800.00,
        paymentMethod: 'cash',
      }),
    });
    expect(payRes2.status).toBe(201);
    const payBody2 = await payRes2.json();

    expect(payBody2.data.purchase.amount_paid).toBe(2000.00);
    expect(payBody2.data.purchase.outstanding_balance).toBe(0);
    expect(payBody2.data.purchase.payment_status).toBe('paid');
  });

  test('POST /api/suppliers/:id/payments rejects payment exceeding invoice outstanding balance', async () => {
    // 1. Create a 500.00 purchase
    const purchRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-OVERPAY-CHECK',
        items: [{ productName: 'Coton hydrophile', quantity: 5, unitCost: 100.00 }],
        amountPaid: 0,
      }),
    });
    const purchData = await purchRes.json();
    const purchaseId = purchData.data.purchase.id;

    // 2. Attempt payment of 600.00 (exceeds 500.00)
    const payRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/payments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        purchaseId,
        amount: 600.00,
      }),
    });

    expect(payRes.status).toBe(400);
    const payBody = await payRes.json();
    expect(payBody.code).toBe('OVERPAYMENT_REJECTED');
  });

  test('POST /api/suppliers/:id/payments without purchaseId allocates FIFO across unpaid purchases', async () => {
    // Supplier has outstanding invoices from previous tests
    const balBeforeRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/balance`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    const balBefore = await balBeforeRes.json();
    const initialDebt = balBefore.data.outstanding_balance;
    expect(initialDebt).toBeGreaterThan(0);

    // Pay 500 towards overall debt
    const payRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/payments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        amount: 500.00,
        paymentMethod: 'cash',
        notes: 'Paiement partiel global',
      }),
    });

    expect(payRes.status).toBe(201);
    const payBody = await payRes.json();
    expect(payBody.data.allocated_purchases).toBeTruthy();
    expect(payBody.data.allocated_purchases.length).toBeGreaterThan(0);

    // Verify balance decreased by 500
    const balAfterRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/balance`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });
    const balAfter = await balAfterRes.json();
    expect(balAfter.data.outstanding_balance).toBe(Math.round((initialDebt - 500.00) * 100) / 100);
  });

  test('GET /api/suppliers/:id returns combined supplier profile with stock valuation and AP ledger stats', async () => {
    const res = await fetch(`${baseUrl}/suppliers/${supplierAId}`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    const supplier = body.data;

    expect(supplier.id).toBe(supplierAId);
    expect(supplier.name).toBe('Fournisseur Médical Central');
    // AP ledger aggregates
    expect(supplier).toHaveProperty('total_purchases_amount');
    expect(supplier).toHaveProperty('total_purchases_paid');
    expect(supplier).toHaveProperty('outstanding_balance');
    expect(supplier).toHaveProperty('purchases_count');
    expect(supplier).toHaveProperty('payments_count');
    // Catalog inventory valuation remains distinct
    expect(supplier).toHaveProperty('total_assigned_inventory_valuation');
    expect(supplier.total_purchases_amount).toBeGreaterThan(0);
  });

  test('GET /api/suppliers lists suppliers with outstanding AP balances', async () => {
    const res = await fetch(`${baseUrl}/suppliers`, {
      headers: { Authorization: `Bearer ${tokenA}` },
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body.data)).toBe(true);

    const target = body.data.find((s) => s.id === supplierAId);
    expect(target).toBeTruthy();
    expect(parseFloat(target.outstanding_balance)).toBeGreaterThan(0);
    expect(parseFloat(target.total_purchases_amount)).toBeGreaterThan(0);
  });

  test('Strict multi-tenant isolation: Company B cannot access or record payments for Company A supplier', async () => {
    // 1. Company B tries to fetch Company A's supplier
    const getRes = await fetch(`${baseUrl}/suppliers/${supplierAId}`, {
      headers: { Authorization: `Bearer ${tokenB}` },
    });
    expect(getRes.status).toBe(404);

    // 2. Company B tries to record a purchase for Company A's supplier
    const purchRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({
        items: [{ productName: 'Hack Item', quantity: 1, unitCost: 100 }],
      }),
    });
    expect(purchRes.status).toBe(404);

    // 3. Company B tries to record a payment for Company A's supplier
    const payRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/payments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({
        amount: 100,
      }),
    });
    expect(payRes.status).toBe(404);
  });

  test('POST /api/sync/batch supports offline supplier_purchase and supplier_payment sync operations', async () => {
    const offlinePurchTx = `sync_tx_purch_${Date.now()}`;
    const offlinePayTx = `sync_tx_pay_${Date.now()}`;

    const syncPayload = {
      operations: [
        {
          id: `op-1-${Date.now()}`,
          clientTransactionId: offlinePurchTx,
          entityType: 'supplier_purchase',
          operationType: 'CREATE',
          payload: {
            supplierId: supplierBId,
            invoiceNumber: 'INV-OFFLINE-SYNC',
            items: [
              { productName: 'Produit Sync Test', quantity: 10, unitCost: 200.00 },
            ],
            amountPaid: 0,
          },
        },
        {
          id: `op-2-${Date.now()}`,
          clientTransactionId: offlinePayTx,
          entityType: 'supplier_payment',
          operationType: 'CREATE',
          payload: {
            supplierId: supplierBId,
            amount: 500.00,
            paymentMethod: 'cash',
            notes: 'Paiement synchronisé hors ligne',
          },
        },
      ],
    };

    const res = await fetch(`${baseUrl}/sync/batch`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify(syncPayload),
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.results).toHaveLength(2);
    expect(body.results[0].status).toBe('synced');
    expect(body.results[1].status).toBe('synced');

    // Verify balance for Company B supplier
    const balRes = await fetch(`${baseUrl}/suppliers/${supplierBId}/balance`, {
      headers: { Authorization: `Bearer ${tokenB}` },
    });
    const balData = await balRes.json();
    // Total was 2000, paid was 500, outstanding = 1500
    expect(balData.data.total_purchases_amount).toBe(2000.00);
    expect(balData.data.outstanding_balance).toBe(1500.00);
  });

  test('POST /api/suppliers/:id/purchases increments catalog product stock automatically and idempotently', async () => {
    // 1. Create a product for Company A with initial stock 10
    const prodRes = await query(
      `INSERT INTO products (company_id, supplier_id, name, purchase_price, selling_price, quantity)
       VALUES ($1, $2, 'Doliprane 500mg Gélules', 120.00, 180.00, 10)
       RETURNING id, quantity`,
      [companyAId, supplierAId],
    );
    const prodId = prodRes.rows[0].id;
    expect(prodRes.rows[0].quantity).toBe(10);

    const clientTx = `tx_stock_purch_${Date.now()}`;

    // 2. Create purchase containing 25 units of this product + 1 custom item
    const res = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-STOCK-001',
        clientTransactionId: clientTx,
        items: [
          { productId: prodId, productName: 'Doliprane 500mg Gélules', quantity: 25, unitCost: 120.00 },
          { productName: 'Sac emballage kraft', quantity: 50, unitCost: 5.00 }, // custom, no productId
        ],
        amountPaid: 0,
      }),
    });

    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.data.purchase.items).toHaveLength(2);

    // 3. Verify stock has increased from 10 to 35
    const checkRes = await query('SELECT quantity FROM products WHERE id = $1', [prodId]);
    expect(checkRes.rows[0].quantity).toBe(35);

    // 4. Retry the purchase with the exact same clientTransactionId (idempotent replay)
    const retryRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-STOCK-001',
        clientTransactionId: clientTx,
        items: [
          { productId: prodId, productName: 'Doliprane 500mg Gélules', quantity: 25, unitCost: 120.00 },
          { productName: 'Sac emballage kraft', quantity: 50, unitCost: 5.00 },
        ],
        amountPaid: 0,
      }),
    });

    expect(retryRes.status).toBe(201);
    const retryBody = await retryRes.json();
    expect(retryBody.data.idempotent).toBe(true);

    // Stock must STILL be 35 — not double-incremented to 60!
    const checkAfterRetry = await query('SELECT quantity FROM products WHERE id = $1', [prodId]);
    expect(checkAfterRetry.rows[0].quantity).toBe(35);

    // 5. Multi-line purchase with same productId in multiple rows
    const multiLineRes = await fetch(`${baseUrl}/suppliers/${supplierAId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-STOCK-002',
        items: [
          { productId: prodId, productName: 'Doliprane 500mg Gélules', quantity: 15, unitCost: 120.00 },
          { productId: prodId, productName: 'Doliprane 500mg Gélules', quantity: 5, unitCost: 120.00 },
        ],
        amountPaid: 0,
      }),
    });

    expect(multiLineRes.status).toBe(201);
    // Stock was 35 + 15 + 5 = 55
    const checkAfterMultiLine = await query('SELECT quantity FROM products WHERE id = $1', [prodId]);
    expect(checkAfterMultiLine.rows[0].quantity).toBe(55);

    // 6. Cross-tenant attempt: Company B tries to create a purchase with Company A's product
    const crossTenantRes = await fetch(`${baseUrl}/suppliers/${supplierBId}/purchases`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({
        invoiceNumber: 'INV-HACK',
        items: [
          { productId: prodId, productName: 'Hacked Product', quantity: 10, unitCost: 100.00 },
        ],
        amountPaid: 0,
      }),
    });
    expect(crossTenantRes.status).toBe(400);

    // Stock remains 55
    const finalStock = await query('SELECT quantity FROM products WHERE id = $1', [prodId]);
    expect(finalStock.rows[0].quantity).toBe(55);
  });
});

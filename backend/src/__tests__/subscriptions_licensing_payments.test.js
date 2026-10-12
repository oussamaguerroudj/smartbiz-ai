const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query, withTransaction } = require('../config/db');
const env = require('../config/env');
const subscriptionConfig = require('../config/subscription');
const subscriptionsService = require('../modules/subscriptions/subscriptions.service');
const paymentsService = require('../modules/payments/payments.service');
const adminService = require('../modules/admin/admin.service');
const supportService = require('../modules/support/support.service');
const { processTrialReminders } = require('../modules/notifications/reminders.service');
const subscriptionsController = require('../modules/subscriptions/subscriptions.controller');

describe('Subscriptions, Licensing, Chargily, CCP, Support, and Admin System', () => {
  let testCompanyId;
  let testUserId;
  let otherCompanyId;
  let otherUserId;
  let superAdminId;

  beforeAll(async () => {
    // 1. Create primary test company and user
    const compRes = await query(
      `INSERT INTO companies (name, business_type, currency, entitlement_type, account_approval_status)
       VALUES ('Acme Test Enterprise', 'company', 'DZD', 'none', 'approved')
       RETURNING id`,
    );
    testCompanyId = compRes.rows[0].id;

    const pwHash = await bcrypt.hash('TestPass123!', 10);
    const userRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Acme Owner', 'acme.owner@test.modiri.ai', $2, 'owner', true)
       RETURNING id`,
      [testCompanyId, pwHash],
    );
    testUserId = userRes.rows[0].id;

    // 2. Create another company for multi-tenant isolation tests
    const otherCompRes = await query(
      `INSERT INTO companies (name, business_type, currency, entitlement_type)
       VALUES ('Beta Other Corp', 'company', 'DZD', 'none')
       RETURNING id`,
    );
    otherCompanyId = otherCompRes.rows[0].id;

    const otherUserRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Beta Owner', 'beta.owner@test.modiri.ai', $2, 'owner', true)
       RETURNING id`,
      [otherCompanyId, pwHash],
    );
    otherUserId = otherUserRes.rows[0].id;

    // 3. Create super admin
    const adminRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Super Admin Tester', 'admin.unit@test.modiri.ai', $2, 'super_admin', true)
       RETURNING id`,
      [testCompanyId, pwHash],
    );
    superAdminId = adminRes.rows[0].id;
  });

  afterAll(async () => {
    // Clean up test data
    await query('DELETE FROM users WHERE id IN ($1, $2, $3)', [testUserId, otherUserId, superAdminId]);
    await query('DELETE FROM companies WHERE id IN ($1, $2)', [testCompanyId, otherCompanyId]);
  });

  describe('1. Business Configuration & Product Contract', () => {
    test('Product details adhere strictly to specifications', () => {
      const product = subscriptionsService.getLifetimeProduct();
      expect(product.price).toBe(15000);
      expect(product.currency).toBe('DZD');
      expect(product.trialDays).toBe(15);
      expect(product.business.ownerName).toBe('Oussama Guerroudj');
      expect(product.business.ownerNameAr).toBe('أسامة قروج');
      expect(product.business.ccpAccount).toBe('00799999002915122873');
      expect(product.business.whatsappUrl).toBe('https://wa.me/213774195871');
    });

    test('WhatsApp number is properly normalized to international Algerian format', () => {
      expect(subscriptionConfig.business.whatsappNormalized).toBe('213774195871');
      expect(subscriptionConfig.business.whatsappUrl).toContain('213774195871');
    });
  });

  describe('2. Entitlements and Trial Lifecycle', () => {
    test('Initial entitlement state is none', async () => {
      const status = await subscriptionsService.getEntitlementStatus(testCompanyId);
      expect(status.entitlementType).toBe('none');
      expect(status.hasAccess).toBe(false);
      expect(status.status).toBe('none');
    });

    test('selectFreeTrial starts 15-day trial and persists UTC timestamps', async () => {
      const result = await subscriptionsService.selectFreeTrial(testCompanyId, testUserId);
      expect(result.entitlementType).toBe('trial');
      expect(result.hasAccess).toBe(true);
      expect(result.status).toBe('active_trial');
      expect(result.trialStartsAt).toBeDefined();
      expect(result.trialEndsAt).toBeDefined();
      expect(result.daysRemaining).toBe(15);

      const status = await subscriptionsService.getEntitlementStatus(testCompanyId);
      expect(status.hasAccess).toBe(true);
      expect(status.entitlementType).toBe('trial');
    });

    test('selectFreeTrial is idempotent: repeated calls do NOT reset or extend trial end date', async () => {
      const initialStatus = await subscriptionsService.getEntitlementStatus(testCompanyId);
      const initialEnds = new Date(initialStatus.trialEndsAt).getTime();

      // Retry selecting free trial
      const secondCall = await subscriptionsService.selectFreeTrial(testCompanyId, testUserId);
      expect(new Date(secondCall.trialEndsAt).getTime()).toBe(initialEnds);
    });
  });

  describe('3. Chargily Pay Electronic Payments & Webhook Verification', () => {
    test('createChargilyCheckout enforces fixed server price (15000 DZD)', async () => {
      const checkout = await paymentsService.createChargilyCheckout({
        companyId: otherCompanyId,
        userId: otherUserId,
      });

      expect(checkout.amount).toBe(15000);
      expect(checkout.currency).toBe('DZD');
      expect(checkout.orderNumber).toMatch(/^ORD-/);
      expect(checkout.status).toBe('pending');
    });

    test('createChargilyCheckout fails closed in production when apiKey is missing', async () => {
      const originalEnv = process.env.NODE_ENV;
      const originalApiKey = subscriptionConfig.chargily.apiKey;
      try {
        process.env.NODE_ENV = 'production';
        subscriptionConfig.chargily.apiKey = null;

        await expect(
          paymentsService.createChargilyCheckout({
            companyId: otherCompanyId,
            userId: otherUserId,
          }),
        ).rejects.toThrow('Chargily electronic payment service is not configured');
      } finally {
        process.env.NODE_ENV = originalEnv;
        subscriptionConfig.chargily.apiKey = originalApiKey;
      }
    });

    test('processChargilyWebhook rejects invalid HMAC-SHA256 signatures', async () => {
      const rawPayload = JSON.stringify({ id: 'evt_test', event: 'checkout.paid' });
      const rawBuffer = Buffer.from(rawPayload);
      const invalidSignature = 'deadbeefdeadbeefdeadbeefdeadbeef';

      // Set temporary test secret
      subscriptionConfig.chargily.secretKey = 'test-secret-key-32-bytes-long-signature';

      await expect(
        paymentsService.processChargilyWebhook({
          rawBody: rawBuffer,
          signatureHeader: invalidSignature,
          eventData: { id: 'evt_test' },
        }),
      ).rejects.toThrow('Invalid webhook signature');
    });

    test('processChargilyWebhook rejects requests with missing signature header when secret is configured', async () => {
      const rawPayload = JSON.stringify({ id: 'evt_test_missing', event: 'checkout.paid' });
      subscriptionConfig.chargily.secretKey = 'test-secret-key-32-bytes-long-signature';

      await expect(
        paymentsService.processChargilyWebhook({
          rawBody: Buffer.from(rawPayload),
          signatureHeader: null,
          eventData: { id: 'evt_test_missing' },
        }),
      ).rejects.toThrow('Missing webhook signature header');
    });

    test('processChargilyWebhook verifies valid signature and activates lifetime license', async () => {
      const secret = 'test-secret-key-32-bytes-long-signature';
      subscriptionConfig.chargily.secretKey = secret;

      // 1. Create pending order for test company
      const checkout = await paymentsService.createChargilyCheckout({
        companyId: otherCompanyId,
        userId: otherUserId,
      });

      const eventPayload = {
        id: `evt_${Date.now()}`,
        type: 'checkout.paid',
        data: {
          id: checkout.orderId,
          status: 'paid',
          amount: 15000,
          currency: 'dzd',
          metadata: {
            order_id: checkout.orderId,
            company_id: otherCompanyId,
          },
        },
      };

      const rawBuffer = Buffer.from(JSON.stringify(eventPayload));
      const validSignature = crypto.createHmac('sha256', secret).update(rawBuffer).digest('hex');

      const webhookResult = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: validSignature,
        eventData: eventPayload,
      });

      expect(webhookResult.status).toBe('activated');

      // Verify that otherCompany now has lifetime license
      const status = await subscriptionsService.getEntitlementStatus(otherCompanyId);
      expect(status.entitlementType).toBe('lifetime');
      expect(status.hasAccess).toBe(true);
      expect(status.status).toBe('lifetime');

      // Verify idempotency: replaying same webhook does not re-process
      const replayResult = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: validSignature,
        eventData: eventPayload,
      });
      expect(replayResult.status).toBe('already_processed');
    });

    test('processChargilyWebhook rejects malformed non-hex or odd-length signatures', async () => {
      subscriptionConfig.chargily.secretKey = 'test-secret-key-32-bytes-long-signature';
      const rawPayload = JSON.stringify({ id: 'evt_malformed' });

      await expect(
        paymentsService.processChargilyWebhook({
          rawBody: Buffer.from(rawPayload),
          signatureHeader: 'not-a-valid-hex-sig-xyz',
          eventData: { id: 'evt_malformed' },
        }),
      ).rejects.toThrow('Invalid webhook signature');
    });

    test('processChargilyWebhook rejects tenant mismatch on order', async () => {
      const secret = 'test-secret-key-32-bytes-long-signature';
      subscriptionConfig.chargily.secretKey = secret;

      await query("UPDATE companies SET entitlement_type = 'trial' WHERE id = $1", [otherCompanyId]);

      const checkout = await paymentsService.createChargilyCheckout({
        companyId: otherCompanyId,
        userId: otherUserId,
      });

      const eventPayload = {
        id: `evt_mismatch_${Date.now()}`,
        type: 'checkout.paid',
        data: {
          id: checkout.orderId,
          status: 'paid',
          amount: 15000,
          currency: 'dzd',
          metadata: {
            order_id: checkout.orderId,
            company_id: testCompanyId, // Mismatched tenant!
          },
        },
      };

      const rawBuffer = Buffer.from(JSON.stringify(eventPayload));
      const validSig = crypto.createHmac('sha256', secret).update(rawBuffer).digest('hex');

      const result = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: validSig,
        eventData: eventPayload,
      });

      expect(result.status).toBe('tenant_mismatch');

      // Verify order was not marked paid
      const orderRes = await query('SELECT status FROM payment_orders WHERE id = $1', [checkout.orderId]);
      expect(orderRes.rows[0].status).toBe('pending');
    });

    test('processChargilyWebhook rejects currency mismatch and flags under_review', async () => {
      const secret = 'test-secret-key-32-bytes-long-signature';
      subscriptionConfig.chargily.secretKey = secret;

      await query("UPDATE companies SET entitlement_type = 'trial' WHERE id = $1", [otherCompanyId]);

      const checkout = await paymentsService.createChargilyCheckout({
        companyId: otherCompanyId,
        userId: otherUserId,
      });

      const eventPayload = {
        id: `evt_curr_${Date.now()}`,
        type: 'checkout.paid',
        data: {
          id: checkout.orderId,
          status: 'paid',
          amount: 15000,
          currency: 'usd', // Mismatched currency!
          metadata: {
            order_id: checkout.orderId,
            company_id: otherCompanyId,
          },
        },
      };

      const rawBuffer = Buffer.from(JSON.stringify(eventPayload));
      const validSig = crypto.createHmac('sha256', secret).update(rawBuffer).digest('hex');

      const result = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: validSig,
        eventData: eventPayload,
      });

      expect(result.status).toBe('currency_mismatch');

      const orderRes = await query('SELECT status FROM payment_orders WHERE id = $1', [checkout.orderId]);
      expect(orderRes.rows[0].status).toBe('under_review');
    });

    test('processChargilyWebhook rejects amount mismatch and flags under_review', async () => {
      const secret = 'test-secret-key-32-bytes-long-signature';
      subscriptionConfig.chargily.secretKey = secret;

      await query("UPDATE companies SET entitlement_type = 'trial' WHERE id = $1", [otherCompanyId]);

      const checkout = await paymentsService.createChargilyCheckout({
        companyId: otherCompanyId,
        userId: otherUserId,
      });

      const eventPayload = {
        id: `evt_amt_${Date.now()}`,
        type: 'checkout.paid',
        data: {
          id: checkout.orderId,
          status: 'paid',
          amount: 5000, // Less than 15000 DZD!
          currency: 'dzd',
          metadata: {
            order_id: checkout.orderId,
            company_id: otherCompanyId,
          },
        },
      };

      const rawBuffer = Buffer.from(JSON.stringify(eventPayload));
      const validSig = crypto.createHmac('sha256', secret).update(rawBuffer).digest('hex');

      const result = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: validSig,
        eventData: eventPayload,
      });

      expect(result.status).toBe('amount_mismatch');

      const orderRes = await query('SELECT status FROM payment_orders WHERE id = $1', [checkout.orderId]);
      expect(orderRes.rows[0].status).toBe('under_review');
    });

    test('processChargilyWebhook failed or pending event never activates license', async () => {
      const secret = 'test-secret-key-32-bytes-long-signature';
      subscriptionConfig.chargily.secretKey = secret;

      await query("UPDATE companies SET entitlement_type = 'trial' WHERE id = $1", [otherCompanyId]);

      const checkout = await paymentsService.createChargilyCheckout({
        companyId: otherCompanyId,
        userId: otherUserId,
      });

      // 1. Pending event
      const pendingPayload = {
        id: `evt_pend_${Date.now()}`,
        type: 'checkout.pending',
        data: {
          id: checkout.orderId,
          status: 'pending',
          amount: 15000,
          currency: 'dzd',
          metadata: { order_id: checkout.orderId, company_id: otherCompanyId },
        },
      };
      const pendBuf = Buffer.from(JSON.stringify(pendingPayload));
      const pendSig = crypto.createHmac('sha256', secret).update(pendBuf).digest('hex');

      const pendRes = await paymentsService.processChargilyWebhook({
        rawBody: pendBuf,
        signatureHeader: pendSig,
        eventData: pendingPayload,
      });
      expect(pendRes.status).toBe('pending');

      // 2. Failed event
      const failedPayload = {
        id: `evt_fail_${Date.now()}`,
        type: 'checkout.failed',
        data: {
          id: checkout.orderId,
          status: 'failed',
          amount: 15000,
          currency: 'dzd',
          metadata: { order_id: checkout.orderId, company_id: otherCompanyId },
        },
      };
      const failBuf = Buffer.from(JSON.stringify(failedPayload));
      const failSig = crypto.createHmac('sha256', secret).update(failBuf).digest('hex');

      const failRes = await paymentsService.processChargilyWebhook({
        rawBody: failBuf,
        signatureHeader: failSig,
        eventData: failedPayload,
      });
      expect(failRes.status).toBe('failed');

      const orderRes = await query('SELECT status FROM payment_orders WHERE id = $1', [checkout.orderId]);
      expect(orderRes.rows[0].status).toBe('failed');
    });
  });

  describe('4. Manual CCP Payment & Receipt Upload', () => {
    let manualReqId;

    test('createManualPaymentRequest creates pending request with CCP instructions', async () => {
      const result = await paymentsService.createManualPaymentRequest({
        companyId: testCompanyId,
        userId: testUserId,
        transferReference: 'CCP-REF-998877',
      });

      expect(result.requestId).toBeDefined();
      expect(result.amount).toBe(15000);
      expect(result.status).toBe('pending');
      expect(result.ccpDetails.ccpAccount).toBe('00799999002915122873');
      manualReqId = result.requestId;
    });

    test('uploadReceipt rejects spoofed or empty files', async () => {
      const fakeBuffer = Buffer.from('NOT A REAL JPEG IMAGE');
      await expect(
        paymentsService.uploadReceipt({
          requestId: manualReqId,
          companyId: testCompanyId,
          userId: testUserId,
          fileBuffer: fakeBuffer,
          originalFilename: 'fake.jpg',
          mimeType: 'image/jpeg',
        }),
      ).rejects.toThrow('Invalid JPEG file content');
    });

    test('uploadReceipt accepts valid JPEG magic bytes and updates status to under_review', async () => {
      // Valid JPEG header: FF D8 FF E0
      const validJpgHeader = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);
      const result = await paymentsService.uploadReceipt({
        requestId: manualReqId,
        companyId: testCompanyId,
        userId: testUserId,
        fileBuffer: validJpgHeader,
        originalFilename: 'ccp_receipt.jpg',
        mimeType: 'image/jpeg',
      });

      expect(result.status).toBe('under_review');
    });

    test('Tenant Isolation: other user cannot access private receipt', async () => {
      const reqList = await query(
        'SELECT receipt_storage_path FROM manual_payment_requests WHERE id = $1',
        [manualReqId],
      );
      const filename = reqList.rows[0].receipt_storage_path;

      // Other user attempt to view receipt
      await expect(
        paymentsService.getReceiptFile(filename, {
          id: otherUserId,
          companyId: otherCompanyId,
          role: 'owner',
        }),
      ).rejects.toThrow('Unauthorized access to private receipt');

      // Super admin can access receipt
      const adminAccess = await paymentsService.getReceiptFile(filename, {
        id: superAdminId,
        companyId: testCompanyId,
        role: 'super_admin',
      });
      expect(adminAccess.filePath).toBeDefined();
    });

    test('uploadReceipt alone leaves company entitlement as trial (does not activate license)', async () => {
      const status = await subscriptionsService.getEntitlementStatus(testCompanyId);
      expect(status.entitlementType).toBe('trial');
      expect(status.status).toBe('active_trial');
    });

    test('getReceiptFile rejects path traversal attempts with 400 Bad Request', async () => {
      await expect(
        paymentsService.getReceiptFile('../../etc/passwd', {
          id: superAdminId,
          companyId: testCompanyId,
          role: 'super_admin',
        }),
      ).rejects.toThrow('Invalid file name');

      await expect(
        paymentsService.getReceiptFile('malicious_payload.exe', {
          id: superAdminId,
          companyId: testCompanyId,
          role: 'super_admin',
        }),
      ).rejects.toThrow('Invalid file name');
    });

    test('listManualPayments excludes receipt_data bytea buffer from query results', async () => {
      const payments = await adminService.listManualPayments();
      expect(payments.length).toBeGreaterThan(0);
      for (const p of payments) {
        expect(p.receipt_data).toBeUndefined();
      }
    });
  });

  describe('5. Administrator Review and License Actions', () => {
    test('Non-admin user cannot login to admin portal', async () => {
      await expect(
        adminService.adminLogin({
          email: 'acme.owner@test.modiri.ai',
          password: 'TestPass123!',
        }),
      ).rejects.toThrow('Administrative privileges required');
    });

    test('Super admin can login and receive administrative token', async () => {
      const loginRes = await adminService.adminLogin({
        email: 'admin.unit@test.modiri.ai',
        password: 'TestPass123!',
      });
      expect(loginRes.accessToken).toBeDefined();
      expect(loginRes.admin.role).toBe('super_admin');
    });

    test('getOverviewMetrics returns real counted KPIs', async () => {
      const metrics = await adminService.getOverviewMetrics();
      expect(metrics.totalAccounts).toBeGreaterThan(0);
      expect(metrics.verifiedAccounts).toBeGreaterThan(0);
      expect(metrics.activeTrials).toBeGreaterThanOrEqual(1);
      expect(metrics.lifetimeLicenses).toBeGreaterThanOrEqual(0);
    });

    test('listUsers supports searching and filtering', async () => {
      const result = await adminService.listUsers({ search: 'Acme', page: 1, limit: 10 });
      expect(result.users.length).toBeGreaterThanOrEqual(1);
      expect(result.users.some((u) => u.name === 'Acme Owner')).toBe(true);
    });

    test('grantTemporaryLicense grants exact preset duration and logs audit entry', async () => {
      const grantRes = await adminService.grantTemporaryLicense({
        companyId: testCompanyId,
        adminId: superAdminId,
        durationPreset: '1m',
        reason: 'Authorized 1 month extension for testing',
      });

      expect(grantRes.entitlementType).toBe('temporary');
      expect(grantRes.licenseExpiresAt).toBeDefined();

      const auditRes = await adminService.getAuditLogs({ limit: 5 });
      const latestAudit = auditRes.find((a) => a.company_id === testCompanyId && a.action === 'grant_temporary');
      expect(latestAudit).toBeDefined();
      expect(latestAudit.reason).toContain('1 month extension');
    });

    test('extendTemporaryLicense adds specified days to valid expiration', async () => {
      const statusBefore = await subscriptionsService.getEntitlementStatus(testCompanyId);
      const expBefore = new Date(statusBefore.expiresAt).getTime();

      const extendRes = await adminService.extendTemporaryLicense({
        companyId: testCompanyId,
        adminId: superAdminId,
        daysToAdd: 15,
        reason: 'Customer requested 15 days addition',
      });

      const expAfter = new Date(extendRes.newExpiresAt).getTime();
      expect(expAfter - expBefore).toBe(15 * 24 * 60 * 60 * 1000);
    });

    test('setAccountSuspension suspends company and updates audit log', async () => {
      const suspendRes = await adminService.setAccountSuspension({
        companyId: testCompanyId,
        adminId: superAdminId,
        isSuspended: true,
        reason: 'Suspected fraudulent activity',
      });
      expect(suspendRes.isSuspended).toBe(true);

      const status = await subscriptionsService.getEntitlementStatus(testCompanyId);
      expect(status.hasAccess).toBe(false);
      expect(status.isSuspended).toBe(true);

      // Restore access
      const restoreRes = await adminService.setAccountSuspension({
        companyId: testCompanyId,
        adminId: superAdminId,
        isSuspended: false,
        reason: 'Cleared by compliance',
      });
      expect(restoreRes.isSuspended).toBe(false);
    });

    test('decideManualPayment approve grants lifetime license and updates order status', async () => {
      const payments = await adminService.listManualPayments();
      const testPayment = payments.find((p) => p.company_id === testCompanyId);

      const approval = await adminService.decideManualPayment({
        requestId: testPayment.id,
        adminId: superAdminId,
        decision: 'approve',
      });

      expect(approval.status).toBe('approved');

      const status = await subscriptionsService.getEntitlementStatus(testCompanyId);
      expect(status.entitlementType).toBe('lifetime');
      expect(status.hasAccess).toBe(true);
    });

    test('decideManualPayment rejects duplicate transfer reference already approved for another request', async () => {
      // 1. Create a second request with same reference for another company
      await query("UPDATE companies SET entitlement_type = 'trial' WHERE id = $1", [otherCompanyId]);

      const dupReq = await paymentsService.createManualPaymentRequest({
        companyId: otherCompanyId,
        userId: otherUserId,
        transferReference: 'CCP-REF-998877', // Same as testPayment / manualReqId
      });

      // 2. Upload dummy receipt
      const validJpgHeader = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);
      await paymentsService.uploadReceipt({
        requestId: dupReq.requestId,
        companyId: otherCompanyId,
        userId: otherUserId,
        fileBuffer: validJpgHeader,
        originalFilename: 'dup.jpg',
        mimeType: 'image/jpeg',
      });

      // 3. Attempt to approve second request with duplicate reference -> MUST be rejected!
      await expect(
        adminService.decideManualPayment({
          requestId: dupReq.requestId,
          adminId: superAdminId,
          decision: 'approve',
        }),
      ).rejects.toThrow(/already been approved/i);
    });
  });

  describe('6. Support Inquiries and Customer Feedback', () => {
    test('submitContactMessage validates input and saves inquiry with ticket number', async () => {
      const res = await supportService.submitContactMessage({
        name: 'Fatima Zohra',
        email: 'fatima@example.dz',
        phone: '0555123456',
        category: 'payment_license',
        subject: 'Need help with CCP transfer',
        message: 'Hello, I made a transfer via CCP and would like to confirm my receipt.',
      });

      expect(res.ticketNumber).toMatch(/^TIC-/);
      expect(res.status).toBe('new');

      const messages = await adminService.listSupportMessages({ status: 'new' });
      const found = messages.find((m) => m.ticket_number === res.ticketNumber);
      expect(found).toBeDefined();
      expect(found.email).toBe('fatima@example.dz');
    });

    test('submitFeedback validates rating and message', async () => {
      const res = await supportService.submitFeedback({
        category: 'ux_feedback',
        message: 'The new dashboard is intuitive and very fast!',
        rating: 5,
        userId: testUserId,
        companyId: testCompanyId,
      });

      expect(res.status).toBe('new');

      const feedbackList = await adminService.listFeedback({ status: 'new' });
      const found = feedbackList.find((f) => f.id === res.feedbackId);
      expect(found).toBeDefined();
      expect(found.rating).toBe(5);
    });
  });

  describe('7. Trial Expiration Notifications & Scheduled Trigger Workflow', () => {
    const TEST_SCHEDULER_SECRET = 'super-secure-high-entropy-scheduler-secret-2026';

    test('cronProcessReminders rejects requests when SCHEDULER_SECRET is unconfigured on server', async () => {
      const prevSecret = process.env.SCHEDULER_SECRET;
      delete process.env.SCHEDULER_SECRET;
      delete process.env.CRON_SECRET;

      const req = { headers: { 'x-scheduler-secret': 'some-secret' } };
      let error = null;
      try {
        await subscriptionsController.cronProcessReminders(req, {}, (err) => { error = err; });
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.statusCode).toBe(403);
      expect(error.code).toBe('SCHEDULER_UNCONFIGURED');

      process.env.SCHEDULER_SECRET = prevSecret;
    });

    test('cronProcessReminders rejects requests with missing or empty scheduler secret', async () => {
      process.env.SCHEDULER_SECRET = TEST_SCHEDULER_SECRET;

      const req = { headers: {} };
      let error = null;
      try {
        await subscriptionsController.cronProcessReminders(req, {}, (err) => { error = err; });
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.statusCode).toBe(401);
      expect(error.code).toBe('MISSING_SCHEDULER_SECRET');
    });

    test('cronProcessReminders rejects requests with invalid scheduler secret using timing-safe comparison', async () => {
      process.env.SCHEDULER_SECRET = TEST_SCHEDULER_SECRET;

      const req = { headers: { 'x-scheduler-secret': 'wrong-scheduler-secret' } };
      let error = null;
      try {
        await subscriptionsController.cronProcessReminders(req, {}, (err) => { error = err; });
      } catch (err) {
        error = err;
      }

      expect(error).toBeDefined();
      expect(error.statusCode).toBe(401);
      expect(error.code).toBe('INVALID_SCHEDULER_SECRET');
    });

    test('cronProcessReminders succeeds with valid secret and returns aggregated summary (tenant isolation)', async () => {
      process.env.SCHEDULER_SECRET = TEST_SCHEDULER_SECRET;

      let resData = null;
      const res = {
        json: (payload) => {
          resData = payload;
          return res;
        },
      };

      // Test with custom header x-scheduler-secret
      const req = { headers: { 'x-scheduler-secret': TEST_SCHEDULER_SECRET } };
      await subscriptionsController.cronProcessReminders(req, res, () => {});

      expect(resData).toBeDefined();
      expect(resData.success).toBe(true);
      expect(resData.data.processed48h).toBeDefined();
      expect(resData.data.processed24h).toBeDefined();
      expect(resData.data.processedExpired).toBeDefined();
      expect(resData.data.timestamp).toBeDefined();

      // Tenant isolation: verify NO company IDs, user IDs, or names are returned
      expect(resData.data.companyId).toBeUndefined();
      expect(resData.data.email).toBeUndefined();
      expect(resData.data.users).toBeUndefined();

      // Also test with Authorization: Bearer <secret>
      let resBearerData = null;
      const resBearer = { json: (payload) => { resBearerData = payload; return resBearer; } };
      const reqBearer = { headers: { authorization: `Bearer ${TEST_SCHEDULER_SECRET}` } };
      await subscriptionsController.cronProcessReminders(reqBearer, resBearer, () => {});

      expect(resBearerData.success).toBe(true);
    });

    test('processTrialReminders accurately evaluates 48h, 24h, and expired windows and ignores >48h', async () => {
      const now = new Date();

      // 1. Company 48h: expiring in 36h (qualifies for 48h reminder)
      const ends36h = new Date(now.getTime() + 36 * 60 * 60 * 1000);
      const c48Res = await query(
        `INSERT INTO companies (name, business_type, entitlement_type, trial_starts_at, trial_ends_at, account_approval_status)
         VALUES ('Co 48h Due', 'company', 'trial', now(), $1, 'approved') RETURNING id`,
        [ends36h],
      );
      const c48Id = c48Res.rows[0].id;
      const u48Res = await query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Owner 48h', 'c48h@test.modiri.ai', 'hash', 'owner', true) RETURNING id`,
        [c48Id],
      );

      // 2. Company 24h: expiring in 12h (qualifies for 24h reminder)
      const ends12h = new Date(now.getTime() + 12 * 60 * 60 * 1000);
      const c24Res = await query(
        `INSERT INTO companies (name, business_type, entitlement_type, trial_starts_at, trial_ends_at, account_approval_status)
         VALUES ('Co 24h Due', 'company', 'trial', now(), $1, 'approved') RETURNING id`,
        [ends12h],
      );
      const c24Id = c24Res.rows[0].id;
      const u24Res = await query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Owner 24h', 'c24h@test.modiri.ai', 'hash', 'owner', true) RETURNING id`,
        [c24Id],
      );

      // 3. Company Expired: expired 1h ago (qualifies for expired reminder)
      const endsPast = new Date(now.getTime() - 1 * 60 * 60 * 1000);
      const cExpRes = await query(
        `INSERT INTO companies (name, business_type, entitlement_type, trial_starts_at, trial_ends_at, account_approval_status)
         VALUES ('Co Expired Due', 'company', 'trial', now(), $1, 'approved') RETURNING id`,
        [endsPast],
      );
      const cExpId = cExpRes.rows[0].id;
      const uExpRes = await query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Owner Exp', 'cexp@test.modiri.ai', 'hash', 'owner', true) RETURNING id`,
        [cExpId],
      );

      // 4. Company Outside Window: expiring in 60h (too far, must NOT receive any reminder)
      const ends60h = new Date(now.getTime() + 60 * 60 * 60 * 1000);
      const cFarRes = await query(
        `INSERT INTO companies (name, business_type, entitlement_type, trial_starts_at, trial_ends_at, account_approval_status)
         VALUES ('Co Far Future', 'company', 'trial', now(), $1, 'approved') RETURNING id`,
        [ends60h],
      );
      const cFarId = cFarRes.rows[0].id;
      const uFarRes = await query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Owner Far', 'cfar@test.modiri.ai', 'hash', 'owner', true) RETURNING id`,
        [cFarId],
      );

      // 5. Company Upgraded: expiring in 12h but entitlement_type is 'lifetime' (must NOT receive reminder)
      const cLifeRes = await query(
        `INSERT INTO companies (name, business_type, entitlement_type, trial_starts_at, trial_ends_at, account_approval_status)
         VALUES ('Co Upgraded Lifetime', 'company', 'lifetime', now(), $1, 'approved') RETURNING id`,
        [ends12h],
      );
      const cLifeId = cLifeRes.rows[0].id;
      const uLifeRes = await query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Owner Life', 'clife@test.modiri.ai', 'hash', 'owner', true) RETURNING id`,
        [cLifeId],
      );

      // Execute processor
      const runResult = await processTrialReminders();
      expect(runResult.processed48h).toBeGreaterThanOrEqual(1);
      expect(runResult.processed24h).toBeGreaterThanOrEqual(1);
      expect(runResult.processedExpired).toBeGreaterThanOrEqual(1);

      // Verify targeted notifications
      const notif48 = await query('SELECT * FROM notifications WHERE company_id = $1', [c48Id]);
      expect(notif48.rows.length).toBe(1);
      expect(notif48.rows[0].type).toBe('trial_reminder_48h');

      const notif24 = await query('SELECT * FROM notifications WHERE company_id = $1', [c24Id]);
      expect(notif24.rows.length).toBe(1);
      expect(notif24.rows[0].type).toBe('trial_reminder_24h');

      const notifExp = await query('SELECT * FROM notifications WHERE company_id = $1', [cExpId]);
      expect(notifExp.rows.length).toBe(1);
      expect(notifExp.rows[0].type).toBe('trial_expired');

      const notifFar = await query('SELECT * FROM notifications WHERE company_id = $1', [cFarId]);
      expect(notifFar.rows.length).toBe(0);

      const notifLife = await query('SELECT * FROM notifications WHERE company_id = $1', [cLifeId]);
      expect(notifLife.rows.length).toBe(0);

      // Verify audit logs in license_audit_logs
      const audit48 = await query("SELECT * FROM license_audit_logs WHERE company_id = $1 AND action = 'trial_reminder_48h'", [c48Id]);
      expect(audit48.rows.length).toBe(1);

      // Concurrent invocations test: running two processors simultaneously must not duplicate notifications
      await Promise.all([processTrialReminders(), processTrialReminders()]);

      const notif48After = await query('SELECT * FROM notifications WHERE company_id = $1', [c48Id]);
      expect(notif48After.rows.length).toBe(1);

      // Clean up test data
      await query('DELETE FROM users WHERE id IN ($1, $2, $3, $4, $5)', [
        u48Res.rows[0].id, u24Res.rows[0].id, uExpRes.rows[0].id, uFarRes.rows[0].id, uLifeRes.rows[0].id,
      ]);
      await query('DELETE FROM companies WHERE id IN ($1, $2, $3, $4, $5)', [c48Id, c24Id, cExpId, cFarId, cLifeId]);
    });
  });
});

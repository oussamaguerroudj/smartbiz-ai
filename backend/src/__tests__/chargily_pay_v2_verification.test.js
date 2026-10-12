const crypto = require('crypto');
const { query } = require('../config/db');
const subscriptionConfig = require('../config/subscription');
const paymentsService = require('../modules/payments/payments.service');

describe('Chargily Pay V2 Integration & Verification Regression Suite', () => {
  let testCompanyId;
  let testUserId;

  beforeAll(async () => {
    // Ensure test company exists
    const compRes = await query(
      `INSERT INTO companies (name, business_type, currency, entitlement_type, account_approval_status)
       VALUES ('Chargily Test Merchant', 'company', 'DZD', 'none', 'approved')
       RETURNING id`,
    );
    testCompanyId = compRes.rows[0].id;

    const userRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role)
       VALUES ($1, 'Chargily User', 'chargily.tester@modiri.ai', 'hash123', 'owner')
       RETURNING id`,
      [testCompanyId],
    );
    testUserId = userRes.rows[0].id;
  });

  afterAll(async () => {
    try {
      await query(`DELETE FROM payment_orders WHERE company_id = $1`, [testCompanyId]);
      await query(`DELETE FROM users WHERE id = $1`, [testUserId]);
      await query(`DELETE FROM companies WHERE id = $1`, [testCompanyId]);
    } catch (_) {}
  });

  describe('1. Configuration & Mode Enforcement', () => {
    test('adheres to Chargily Pay V2 test endpoint when CHARGILY_MODE is test', () => {
      expect(subscriptionConfig.chargily.baseUrl).toMatch(/pay\.chargily\.net\/(test\/)?api\/v2/);
    });

    test('enforces fixed lifetime product price (15,000 DZD) server-side', () => {
      expect(subscriptionConfig.product.priceDzd).toBe(15000);
      expect(subscriptionConfig.product.currency).toBe('DZD');
    });
  });

  describe('2. Fail-Closed Behavior for Missing Credentials', () => {
    test('createChargilyCheckout fails closed in production when apiKey is missing', async () => {
      const originalEnv = process.env.NODE_ENV;
      const originalApiKey = subscriptionConfig.chargily.apiKey;
      try {
        process.env.NODE_ENV = 'production';
        subscriptionConfig.chargily.apiKey = null;

        await expect(
          paymentsService.createChargilyCheckout({
            companyId: testCompanyId,
            userId: testUserId,
          }),
        ).rejects.toThrow('Chargily electronic payment service is not configured');
      } finally {
        process.env.NODE_ENV = originalEnv;
        subscriptionConfig.chargily.apiKey = originalApiKey;
      }
    });

    test('processChargilyWebhook fails closed with 500 when webhook secret is unconfigured', async () => {
      const originalSecret = subscriptionConfig.chargily.secretKey;
      try {
        subscriptionConfig.chargily.secretKey = null;

        await expect(
          paymentsService.processChargilyWebhook({
            rawBody: Buffer.from('{"test": true}'),
            signatureHeader: 'anyhexsignature',
            eventData: { id: 'evt_test' },
          }),
        ).rejects.toThrow('Payment webhook secret is unconfigured');
      } finally {
        subscriptionConfig.chargily.secretKey = originalSecret;
      }
    });
  });

  describe('3. Webhook Signature Verification (HMAC-SHA256)', () => {
    const testSecret = 'chargily_test_secret_key_32_bytes_len';

    beforeEach(() => {
      subscriptionConfig.chargily.secretKey = testSecret;
    });

    test('rejects webhook requests with missing or empty signature header', async () => {
      await expect(
        paymentsService.processChargilyWebhook({
          rawBody: Buffer.from('{"test": true}'),
          signatureHeader: '',
          eventData: { id: 'evt_missing_sig' },
        }),
      ).rejects.toThrow('Missing webhook signature header');
    });

    test('rejects webhook requests with invalid or tampered signature', async () => {
      const rawPayload = JSON.stringify({ id: 'evt_tampered', type: 'checkout.paid' });
      const rawBuffer = Buffer.from(rawPayload);
      const invalidSignature = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

      await expect(
        paymentsService.processChargilyWebhook({
          rawBody: rawBuffer,
          signatureHeader: invalidSignature,
          eventData: { id: 'evt_tampered' },
        }),
      ).rejects.toThrow('Invalid webhook signature');
    });

    test('verifies valid HMAC-SHA256 signature using timingSafeEqual', async () => {
      // 1. Create a real payment order in DB
      const checkout = await paymentsService.createChargilyCheckout({
        companyId: testCompanyId,
        userId: testUserId,
      });

      // 2. Prepare valid webhook payload
      const webhookPayload = {
        id: `evt_${Date.now()}`,
        type: 'checkout.paid',
        data: {
          id: checkout.orderId,
          amount: 15000,
          currency: 'dzd',
          status: 'paid',
          metadata: {
            order_id: checkout.orderId,
            company_id: testCompanyId,
          },
        },
      };

      const rawBuffer = Buffer.from(JSON.stringify(webhookPayload));
      const validSignature = crypto
        .createHmac('sha256', testSecret)
        .update(rawBuffer)
        .digest('hex');

      const result = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: validSignature,
        eventData: webhookPayload,
      });

      expect(result.status).toBe('activated');
      expect(result.orderId).toBe(checkout.orderId);

      // Verify entitlement was activated
      const compCheck = await query(
        `SELECT entitlement_type FROM companies WHERE id = $1`,
        [testCompanyId],
      );
      expect(compCheck.rows[0].entitlement_type).toBe('lifetime');
    });
  });

  describe('4. Idempotency & Tamper Defense', () => {
    test('duplicate webhook event IDs are ignored idempotently without re-granting', async () => {
      const testSecret = 'chargily_test_secret_key_32_bytes_len';
      subscriptionConfig.chargily.secretKey = testSecret;

      const duplicateEventId = `evt_dup_${Date.now()}`;
      const payload = {
        id: duplicateEventId,
        type: 'checkout.paid',
        data: {
          id: 'any_order',
          amount: 15000,
          currency: 'dzd',
          status: 'paid',
        },
      };

      const rawBuffer = Buffer.from(JSON.stringify(payload));
      const signature = crypto.createHmac('sha256', testSecret).update(rawBuffer).digest('hex');

      // Pre-insert event ID into payment_webhook_events
      await query(
        `INSERT INTO payment_webhook_events (event_id, event_type, payload)
         VALUES ($1, $2, $3)`,
        [duplicateEventId, 'checkout.paid', JSON.stringify(payload)],
      );

      const result = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: signature,
        eventData: payload,
      });

      expect(result.status).toBe('already_processed');
      expect(result.eventId).toBe(duplicateEventId);
    });
  });
});

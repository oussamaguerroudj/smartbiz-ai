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

  describe('5. Authoritative Gateway Checks & Tamper Resistance', () => {
    const testSecret = 'chargily_test_secret_key_32_bytes_len';

    beforeEach(async () => {
      subscriptionConfig.chargily.secretKey = testSecret;
      await query(`UPDATE companies SET entitlement_type = 'none' WHERE id = $1`, [testCompanyId]);
    });

    test('webhook rejects test mode event when Chargily mode is live', async () => {
      const originalMode = subscriptionConfig.chargily.mode;
      try {
        subscriptionConfig.chargily.mode = 'live';

        const checkout = await paymentsService.createChargilyCheckout({
          companyId: testCompanyId,
          userId: testUserId,
        });

        const testEventPayload = {
          id: `evt_test_livemode_${Date.now()}`,
          type: 'checkout.paid',
          data: {
            id: checkout.orderId,
            amount: 15000,
            currency: 'dzd',
            status: 'paid',
            livemode: false, // Sandbox event sent to live backend
            metadata: {
              order_id: checkout.orderId,
              company_id: testCompanyId,
            },
          },
        };

        const rawBuffer = Buffer.from(JSON.stringify(testEventPayload));
        const sig = crypto.createHmac('sha256', testSecret).update(rawBuffer).digest('hex');

        const result = await paymentsService.processChargilyWebhook({
          rawBody: rawBuffer,
          signatureHeader: sig,
          eventData: testEventPayload,
        });

        expect(result.status).toBe('livemode_mismatch');

        // Order must be under_review, company must NOT be lifetime
        const orderRes = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
        expect(orderRes.rows[0].status).toBe('under_review');
      } finally {
        subscriptionConfig.chargily.mode = originalMode;
      }
    });

    test('webhook does not activate license if eventType is not checkout.paid or payment.paid', async () => {
      const checkout = await paymentsService.createChargilyCheckout({
        companyId: testCompanyId,
        userId: testUserId,
      });

      const pendingEventPayload = {
        id: `evt_pending_${Date.now()}`,
        type: 'checkout.created',
        data: {
          id: checkout.orderId,
          amount: 15000,
          currency: 'dzd',
          status: 'pending',
          metadata: {
            order_id: checkout.orderId,
            company_id: testCompanyId,
          },
        },
      };

      const rawBuffer = Buffer.from(JSON.stringify(pendingEventPayload));
      const sig = crypto.createHmac('sha256', testSecret).update(rawBuffer).digest('hex');

      const result = await paymentsService.processChargilyWebhook({
        rawBody: rawBuffer,
        signatureHeader: sig,
        eventData: pendingEventPayload,
      });

      expect(result.status).not.toBe('activated');

      const orderRes = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
      expect(orderRes.rows[0].status).toBe('pending');
    });

    test('getPaymentOrderStatus marks order under_review if gateway reports amount mismatch', async () => {
      const originalFetch = global.fetch;
      const originalApiKey = subscriptionConfig.chargily.apiKey;
      try {
        subscriptionConfig.chargily.apiKey = 'test_api_key_123';

        const checkout = await paymentsService.createChargilyCheckout({
          companyId: testCompanyId,
          userId: testUserId,
        });

        // Mock gateway returning status: paid, but amount: 500 DZD instead of 15000
        global.fetch = jest.fn().mockResolvedValue({
          ok: true,
          json: async () => ({
            id: checkout.orderId,
            status: 'paid',
            amount: 500, // Mismatch!
            currency: 'dzd',
            metadata: { company_id: testCompanyId },
          }),
        });

        const statusRes = await paymentsService.getPaymentOrderStatus(testCompanyId, checkout.orderId);
        expect(statusRes.status).toBe('under_review');

        const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
        expect(orderCheck.rows[0].status).toBe('under_review');
      } finally {
        global.fetch = originalFetch;
        subscriptionConfig.chargily.apiKey = originalApiKey;
      }
    });

    test('getPaymentOrderStatus marks order under_review if gateway reports company_id mismatch', async () => {
      const originalFetch = global.fetch;
      const originalApiKey = subscriptionConfig.chargily.apiKey;
      try {
        const checkout = await paymentsService.createChargilyCheckout({
          companyId: testCompanyId,
          userId: testUserId,
        });

        subscriptionConfig.chargily.apiKey = 'test_api_key_123';

        // Mock gateway returning status: paid, but company_id of a different tenant
        global.fetch = jest.fn().mockResolvedValue({
          ok: true,
          json: async () => ({
            id: checkout.orderId,
            status: 'paid',
            amount: 15000,
            currency: 'dzd',
            metadata: { company_id: 'other_foreign_company' }, // Cross-tenant spoof attempt!
          }),
        });

        const statusRes = await paymentsService.getPaymentOrderStatus(testCompanyId, checkout.orderId);
        expect(statusRes.status).toBe('under_review');

        const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
        expect(orderCheck.rows[0].status).toBe('under_review');
      } finally {
        global.fetch = originalFetch;
        subscriptionConfig.chargily.apiKey = originalApiKey;
      }
    });

    test('createChargilyCheckout fails closed in production when Chargily mode is test', async () => {
      const origEnv = process.env.NODE_ENV;
      const origMode = subscriptionConfig.chargily.mode;
      const origBaseUrl = subscriptionConfig.chargily.baseUrl;
      const origApiKey = subscriptionConfig.chargily.apiKey;

      try {
        process.env.NODE_ENV = 'production';
        subscriptionConfig.chargily.mode = 'test';
        subscriptionConfig.chargily.baseUrl = 'https://pay.chargily.net/test/api/v2';
        subscriptionConfig.chargily.apiKey = 'test_key';

        await expect(
          paymentsService.createChargilyCheckout({
            companyId: testCompanyId,
            userId: testUserId,
          })
        ).rejects.toThrow('Chargily electronic payment is misconfigured for production mode');
      } finally {
        process.env.NODE_ENV = origEnv;
        subscriptionConfig.chargily.mode = origMode;
        subscriptionConfig.chargily.baseUrl = origBaseUrl;
        subscriptionConfig.chargily.apiKey = origApiKey;
      }
    });

    test('createChargilyCheckout fails closed in production when API key is missing', async () => {
      const origEnv = process.env.NODE_ENV;
      const origMode = subscriptionConfig.chargily.mode;
      const origBaseUrl = subscriptionConfig.chargily.baseUrl;
      const origApiKey = subscriptionConfig.chargily.apiKey;

      try {
        process.env.NODE_ENV = 'production';
        subscriptionConfig.chargily.mode = 'live';
        subscriptionConfig.chargily.baseUrl = 'https://pay.chargily.net/api/v2';
        subscriptionConfig.chargily.apiKey = null;

        await expect(
          paymentsService.createChargilyCheckout({
            companyId: testCompanyId,
            userId: testUserId,
          })
        ).rejects.toThrow('Chargily electronic payment service is not configured');
      } finally {
        process.env.NODE_ENV = origEnv;
        subscriptionConfig.chargily.mode = origMode;
        subscriptionConfig.chargily.baseUrl = origBaseUrl;
        subscriptionConfig.chargily.apiKey = origApiKey;
      }
    });

    test('webhook rejects underpayment and overpayment, setting status to under_review', async () => {
      const checkout = await paymentsService.createChargilyCheckout({
        companyId: testCompanyId,
        userId: testUserId,
      });

      // Test underpayment: 14999 instead of 15000
      const underpayPayload = {
        id: `evt_underpay_${Date.now()}`,
        type: 'checkout.paid',
        data: {
          id: checkout.orderId,
          amount: 14999,
          currency: 'dzd',
          status: 'paid',
          metadata: {
            order_id: checkout.orderId,
            company_id: testCompanyId,
            user_id: testUserId,
          },
        },
      };

      const underpayBuffer = Buffer.from(JSON.stringify(underpayPayload));
      const underpaySig = crypto.createHmac('sha256', testSecret).update(underpayBuffer).digest('hex');

      const underpayResult = await paymentsService.processChargilyWebhook({
        rawBody: underpayBuffer,
        signatureHeader: underpaySig,
        eventData: underpayPayload,
      });

      expect(underpayResult.status).toBe('amount_mismatch');
      const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
      expect(orderCheck.rows[0].status).toBe('under_review');

      const companyCheck = await query(`SELECT entitlement_type FROM companies WHERE id = $1`, [testCompanyId]);
      expect(companyCheck.rows[0].entitlement_type).toBe('none');
    });

    test('webhook in live mode rejects event with missing livemode field', async () => {
      const origMode = subscriptionConfig.chargily.mode;
      try {
        subscriptionConfig.chargily.mode = 'live';

        const checkout = await paymentsService.createChargilyCheckout({
          companyId: testCompanyId,
          userId: testUserId,
        });

        const missingLivemodePayload = {
          id: `evt_missing_livemode_${Date.now()}`,
          type: 'checkout.paid',
          data: {
            id: checkout.orderId,
            amount: 15000,
            currency: 'dzd',
            status: 'paid',
            // livemode omitted entirely
            metadata: {
              order_id: checkout.orderId,
              company_id: testCompanyId,
              user_id: testUserId,
            },
          },
        };

        const buf = Buffer.from(JSON.stringify(missingLivemodePayload));
        const sig = crypto.createHmac('sha256', testSecret).update(buf).digest('hex');

        const result = await paymentsService.processChargilyWebhook({
          rawBody: buf,
          signatureHeader: sig,
          eventData: missingLivemodePayload,
        });

        expect(result.status).toBe('livemode_mismatch');
        const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
        expect(orderCheck.rows[0].status).toBe('under_review');
      } finally {
        subscriptionConfig.chargily.mode = origMode;
      }
    });

    test('getPaymentOrderStatus marks order under_review if livemode is missing in live mode', async () => {
      const originalFetch = global.fetch;
      const originalApiKey = subscriptionConfig.chargily.apiKey;
      const origMode = subscriptionConfig.chargily.mode;

      try {
        const checkout = await paymentsService.createChargilyCheckout({
          companyId: testCompanyId,
          userId: testUserId,
        });

        subscriptionConfig.chargily.mode = 'live';
        subscriptionConfig.chargily.apiKey = 'test_api_key_live';

        global.fetch = jest.fn().mockResolvedValue({
          ok: true,
          json: async () => ({
            id: checkout.orderId,
            status: 'paid',
            amount: 15000,
            currency: 'dzd',
            // livemode missing
            metadata: {
              company_id: testCompanyId,
              user_id: testUserId,
              order_id: checkout.orderId,
            },
          }),
        });

        const statusRes = await paymentsService.getPaymentOrderStatus(testCompanyId, checkout.orderId);
        expect(statusRes.status).toBe('under_review');

        const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
        expect(orderCheck.rows[0].status).toBe('under_review');
      } finally {
        global.fetch = originalFetch;
        subscriptionConfig.chargily.apiKey = originalApiKey;
        subscriptionConfig.chargily.mode = origMode;
      }
    });

    test('getPaymentOrderStatus marks order under_review if metadata user_id or order_id mismatches', async () => {
      const originalFetch = global.fetch;
      const originalApiKey = subscriptionConfig.chargily.apiKey;

      try {
        const checkout = await paymentsService.createChargilyCheckout({
          companyId: testCompanyId,
          userId: testUserId,
        });

        subscriptionConfig.chargily.apiKey = 'test_api_key';

        global.fetch = jest.fn().mockResolvedValue({
          ok: true,
          json: async () => ({
            id: checkout.orderId,
            status: 'paid',
            amount: 15000,
            currency: 'dzd',
            metadata: {
              company_id: testCompanyId,
              user_id: 'spoofed_other_user_id', // Spoofed user
              order_id: checkout.orderId,
            },
          }),
        });

        const statusRes = await paymentsService.getPaymentOrderStatus(testCompanyId, checkout.orderId);
        expect(statusRes.status).toBe('under_review');

        const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [checkout.orderId]);
        expect(orderCheck.rows[0].status).toBe('under_review');
      } finally {
        global.fetch = originalFetch;
        subscriptionConfig.chargily.apiKey = originalApiKey;
      }
    });

    test('createChargilyCheckout fails closed in production when public key is provided as API key', async () => {
      const origEnv = process.env.NODE_ENV;
      const origApiKey = subscriptionConfig.chargily.apiKey;
      const origMode = subscriptionConfig.chargily.mode;
      const origBaseUrl = subscriptionConfig.chargily.baseUrl;

      try {
        process.env.NODE_ENV = 'production';
        subscriptionConfig.chargily.mode = 'live';
        subscriptionConfig.chargily.baseUrl = 'https://pay.chargily.net/api/v2';
        subscriptionConfig.chargily.apiKey = 'live_pk_test_public_key_123';

        await expect(
          paymentsService.createChargilyCheckout({
            companyId: testCompanyId,
            userId: testUserId,
          })
        ).rejects.toThrow('public key provided instead of secret API key');
      } finally {
        process.env.NODE_ENV = origEnv;
        subscriptionConfig.chargily.apiKey = origApiKey;
        subscriptionConfig.chargily.mode = origMode;
        subscriptionConfig.chargily.baseUrl = origBaseUrl;
      }
    });

    test('processChargilyWebhook in production rejects test mode event even if chargily.mode is test', async () => {
      const origEnv = process.env.NODE_ENV;
      const origMode = subscriptionConfig.chargily.mode;

      try {
        process.env.NODE_ENV = 'production';
        subscriptionConfig.chargily.mode = 'test';

        const orderRes = await query(
          `INSERT INTO payment_orders (
             order_number, company_id, user_id, product_type, payment_method,
             amount, currency, status, idempotency_key
           ) VALUES ($1, $2, $3, 'lifetime_license', 'chargily', 15000, 'DZD', 'pending', $4)
           RETURNING id`,
          [`ORD-TEST-${Date.now()}`, testCompanyId, testUserId, crypto.randomUUID()],
        );
        const orderId = orderRes.rows[0].id;

        const testEventPayload = {
          id: `evt_prod_test_mode_${Date.now()}`,
          type: 'checkout.paid',
          data: {
            id: orderId,
            amount: 15000,
            currency: 'dzd',
            status: 'paid',
            livemode: false, // Sandbox event
            metadata: {
              order_id: orderId,
              company_id: testCompanyId,
              user_id: testUserId,
            },
          },
        };

        const rawBuffer = Buffer.from(JSON.stringify(testEventPayload));
        const sig = crypto.createHmac('sha256', testSecret).update(rawBuffer).digest('hex');

        const result = await paymentsService.processChargilyWebhook({
          rawBody: rawBuffer,
          signatureHeader: sig,
          eventData: testEventPayload,
        });

        expect(result.status).toBe('livemode_mismatch');

        const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [orderId]);
        expect(orderCheck.rows[0].status).toBe('under_review');

        const compCheck = await query(`SELECT entitlement_type FROM companies WHERE id = $1`, [testCompanyId]);
        expect(compCheck.rows[0].entitlement_type).toBe('none');
      } finally {
        process.env.NODE_ENV = origEnv;
        subscriptionConfig.chargily.mode = origMode;
      }
    });

    test('getPaymentOrderStatus in production marks order under_review if livemode is false even if chargily.mode is test', async () => {
      const origEnv = process.env.NODE_ENV;
      const origMode = subscriptionConfig.chargily.mode;
      const originalFetch = global.fetch;
      const originalApiKey = subscriptionConfig.chargily.apiKey;

      try {
        process.env.NODE_ENV = 'production';
        subscriptionConfig.chargily.mode = 'test';
        subscriptionConfig.chargily.apiKey = 'test_sk_valid_secret_key';

        const orderRes = await query(
          `INSERT INTO payment_orders (
             order_number, company_id, user_id, product_type, payment_method,
             amount, currency, status, idempotency_key, provider_checkout_id
           ) VALUES ($1, $2, $3, 'lifetime_license', 'chargily', 15000, 'DZD', 'pending', $4, $5)
           RETURNING id`,
          [`ORD-RECON-${Date.now()}`, testCompanyId, testUserId, crypto.randomUUID(), `chk_${Date.now()}`],
        );
        const orderId = orderRes.rows[0].id;

        global.fetch = jest.fn().mockResolvedValue({
          ok: true,
          json: async () => ({
            id: `chk_${Date.now()}`,
            status: 'paid',
            amount: 15000,
            currency: 'dzd',
            livemode: false, // Sandbox checkout checked in production
            metadata: {
              company_id: testCompanyId,
              user_id: testUserId,
              order_id: orderId,
            },
          }),
        });

        const statusRes = await paymentsService.getPaymentOrderStatus(testCompanyId, orderId);
        expect(statusRes.status).toBe('under_review');

        const orderCheck = await query(`SELECT status FROM payment_orders WHERE id = $1`, [orderId]);
        expect(orderCheck.rows[0].status).toBe('under_review');
      } finally {
        global.fetch = originalFetch;
        process.env.NODE_ENV = origEnv;
        subscriptionConfig.chargily.mode = origMode;
        subscriptionConfig.chargily.apiKey = originalApiKey;
      }
    });
  });
});

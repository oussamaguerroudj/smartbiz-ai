const http = require('http');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const app = require('../app');
const { query } = require('../config/db');
const env = require('../config/env');
const pushService = require('../modules/notifications/push.service');
const firebaseConfig = require('../config/firebase');

describe('Push Notifications and Device Tokens Suite', () => {
  let server;
  let baseUrl;
  let authToken;
  let userId;
  let companyId;
  let otherCompanyId;
  let otherUserId;
  const testEmail = `push_test_${Date.now()}@test.com`;

  beforeAll(async () => {
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}/api`;

    // Create primary company and user
    const compRes = await query(
      `INSERT INTO companies (name) VALUES ($1) RETURNING id`,
      ['Push Test Co'],
    );
    companyId = compRes.rows[0].id;

    const hash = await bcrypt.hash('TestPass123!', 8);
    const userRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Push User', $2, $3, 'owner', true) RETURNING id`,
      [companyId, testEmail, hash],
    );
    userId = userRes.rows[0].id;

    authToken = jwt.sign(
      { sub: userId, companyId, role: 'owner', emailVerified: true, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );

    // Create a distinct second company and user to verify tenant isolation
    const otherCompRes = await query(
      `INSERT INTO companies (name) VALUES ($1) RETURNING id`,
      ['Isolated Other Co'],
    );
    otherCompanyId = otherCompRes.rows[0].id;

    const otherUserRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Other User', $2, $3, 'owner', true) RETURNING id`,
      [otherCompanyId, `other_${Date.now()}@test.com`, hash],
    );
    otherUserId = otherUserRes.rows[0].id;
  });

  afterAll(async () => {
    if (companyId) {
      await query('DELETE FROM companies WHERE id = $1', [companyId]);
    }
    if (otherCompanyId) {
      await query('DELETE FROM companies WHERE id = $1', [otherCompanyId]);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  test('masks device tokens securely for logging', () => {
    expect(pushService.maskToken(null)).toBe('<empty>');
    expect(pushService.maskToken('')).toBe('<empty>');
    expect(pushService.maskToken('short')).toBe('***');
    const token = 'd7g8h9abcdefghijklmnopqrstuvwxyz1234567890';
    const masked = pushService.maskToken(token);
    expect(masked.startsWith('d7g8h9...')).toBe(true);
    expect(masked.endsWith('7890')).toBe(true);
    expect(masked.includes('abcdefghijklmno')).toBe(false);
  });

  test('registers a device token successfully via authenticated API', async () => {
    const res = await fetch(`${baseUrl}/notifications/device-token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        token: 'fcm_sample_token_valid_123',
        platform: 'android',
        deviceInfo: { model: 'Pixel 8' },
      }),
    });

    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.message).toBe('Device token registered successfully');
    expect(body.data.platform).toBe('android');

    // Verify token exists in database for this specific user and company
    const dbRes = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    expect(dbRes.rows.length).toBe(1);
    expect(dbRes.rows[0].token).toBe('fcm_sample_token_valid_123');
    expect(dbRes.rows[0].company_id).toBe(companyId);
  });

  test('upserts device token idempotently on repeat registration', async () => {
    const res = await fetch(`${baseUrl}/notifications/device-token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        token: 'fcm_sample_token_valid_123',
        platform: 'android',
        deviceInfo: { model: 'Pixel 8 Pro Updated' },
      }),
    });

    expect(res.status).toBe(201);
    const dbRes = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    expect(dbRes.rows.length).toBe(1);
    expect(dbRes.rows[0].device_info.model).toBe('Pixel 8 Pro Updated');
  });

  test('safe fallback when Firebase credentials are unconfigured in environment', async () => {
    // Unconfigured returns simulated result and does not crash or throw
    const result = await pushService.sendPushNotification({
      userId,
      companyId,
      title: 'Reminder Title',
      body: 'Reminder Body',
    });

    expect(result.sent).toBe(0);
    expect(result.simulated).toBe(1);
    expect(result.reason).toBe('unconfigured_credentials');
  });

  test('enforces strict tenant isolation during push targeting', async () => {
    // Register token for user in other company
    await pushService.registerDeviceToken({
      userId: otherUserId,
      companyId: otherCompanyId,
      token: 'fcm_other_company_token_456',
      platform: 'android',
    });

    // Target primary user and company: must NOT select other company's devices
    const result = await pushService.sendPushNotification({
      userId,
      companyId,
      title: 'Tenant Isolation Test',
      body: 'Tenant body',
    });

    // In unconfigured mode, it finds exactly 1 device (the primary user's token)
    expect(result.simulated).toBe(1);

    // Verify database token rows remain cleanly segregated
    const userTokens = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    const otherTokens = await query('SELECT * FROM device_tokens WHERE user_id = $1', [otherUserId]);

    expect(userTokens.rows.length).toBe(1);
    expect(otherTokens.rows.length).toBe(1);
    expect(userTokens.rows[0].company_id).toBe(companyId);
    expect(otherTokens.rows[0].company_id).toBe(otherCompanyId);
  });

  test('successfully sends and prunes invalid/dead tokens when FCM reports registration-token-not-registered', async () => {
    // Register a second token for primary user that will simulate an invalid token
    await pushService.registerDeviceToken({
      userId,
      companyId,
      token: 'fcm_dead_expired_token_999',
      platform: 'android',
    });

    const preTokens = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    expect(preTokens.rows.length).toBe(2);

    // Mock Firebase messaging behavior
    const originalGetMessaging = firebaseConfig.getMessaging;
    const originalIsConfigured = firebaseConfig.isFirebaseConfigured;

    firebaseConfig.isFirebaseConfigured = () => true;
    firebaseConfig.getMessaging = () => ({
      sendEachForMulticast: async (payload) => {
        expect(payload.tokens.length).toBe(2);
        // Verify payload format complies with FCM v1 string data requirement
        expect(typeof payload.notification.title).toBe('string');
        return {
          successCount: 1,
          failureCount: 1,
          responses: [
            { success: true },
            {
              success: false,
              error: {
                code: 'messaging/registration-token-not-registered',
                message: 'Requested entity was not found.',
              },
            },
          ],
        };
      },
    });

    try {
      const dispatchResult = await pushService.sendPushNotification({
        userId,
        companyId,
        title: 'Trial Expiring Soon',
        body: 'Upgrade now',
        data: { type: 'trial_reminder_48h' },
      });

      expect(dispatchResult.sent).toBe(1);
      expect(dispatchResult.failed).toBe(1);
      expect(dispatchResult.pruned).toBe(1);

      // Verify the dead token was automatically removed from the database
      const postTokens = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
      expect(postTokens.rows.length).toBe(1);
      expect(postTokens.rows[0].token).toBe('fcm_sample_token_valid_123');

      // Verify other user's token was completely untouched
      const otherTokens = await query('SELECT * FROM device_tokens WHERE user_id = $1', [otherUserId]);
      expect(otherTokens.rows.length).toBe(1);
      expect(otherTokens.rows[0].token).toBe('fcm_other_company_token_456');
    } finally {
      // Restore original functions
      firebaseConfig.getMessaging = originalGetMessaging;
      firebaseConfig.isFirebaseConfigured = originalIsConfigured;
    }
  });

  test('unregisters device token cleanly on logout', async () => {
    const res = await fetch(`${baseUrl}/notifications/device-token`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        token: 'fcm_sample_token_valid_123',
      }),
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.deleted).toBe(true);

    const dbRes = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    expect(dbRes.rows.length).toBe(0);
  });
});

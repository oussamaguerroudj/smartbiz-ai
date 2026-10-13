const http = require('http');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const app = require('../app');
const { query } = require('../config/db');
const env = require('../config/env');
const pushService = require('../modules/notifications/push.service');

describe('Push Notifications and Device Tokens', () => {
  let server;
  let baseUrl;
  let authToken;
  let userId;
  let companyId;
  const testEmail = `push_test_${Date.now()}@test.com`;

  beforeAll(async () => {
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}/api`;

    // Create company and user directly
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
  });

  afterAll(async () => {
    if (companyId) {
      await query('DELETE FROM companies WHERE id = $1', [companyId]);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  test('registers a device token successfully', async () => {
    const res = await fetch(`${baseUrl}/notifications/device-token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        token: 'fcm_sample_token_12345',
        platform: 'android',
        deviceInfo: { model: 'Pixel 8' },
      }),
    });

    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.message).toBe('Device token registered successfully');
    expect(body.data.platform).toBe('android');

    // Verify token exists in database
    const dbRes = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    expect(dbRes.rows.length).toBe(1);
    expect(dbRes.rows[0].token).toBe('fcm_sample_token_12345');
  });

  test('upserts device token idempotently on repeat registration', async () => {
    const res = await fetch(`${baseUrl}/notifications/device-token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        token: 'fcm_sample_token_12345',
        platform: 'android',
        deviceInfo: { model: 'Pixel 8 Pro Updated' },
      }),
    });

    expect(res.status).toBe(201);
    const dbRes = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    expect(dbRes.rows.length).toBe(1);
  });

  test('pushService finds and dispatches to registered devices', async () => {
    const result = await pushService.sendPushNotification({
      userId,
      companyId,
      title: 'Test Push Title',
      body: 'Test Push Body Content',
    });

    expect(result.sent).toBe(1);
    expect(result.title).toBe('Test Push Title');
  });

  test('unregisters device token', async () => {
    const res = await fetch(`${baseUrl}/notifications/device-token`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        token: 'fcm_sample_token_12345',
      }),
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.data.deleted).toBe(true);

    const dbRes = await query('SELECT * FROM device_tokens WHERE user_id = $1', [userId]);
    expect(dbRes.rows.length).toBe(0);
  });
});

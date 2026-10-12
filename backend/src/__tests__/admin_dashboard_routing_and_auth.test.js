const http = require('http');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../config/db');
const env = require('../config/env');
const app = require('../app');

describe('Admin Dashboard Routing, Static SPA & Privileged Authorization Suite', () => {
  let server;
  let baseUrl;
  let superAdminId;
  let supportUserId;
  let regularUserId;
  let testCompanyId;

  let superAdminToken;
  let supportToken;
  let regularUserToken;

  const adminPassword = 'AdminSecretPassword123!';

  beforeAll(async () => {
    // 1. Start test server
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}`;

    // 2. Setup system admin company
    let adminCompId;
    const compRes = await query(`SELECT id FROM companies WHERE name = 'Modiri Administration' LIMIT 1`);
    if (compRes.rows.length > 0) {
      adminCompId = compRes.rows[0].id;
    } else {
      const newComp = await query(
        `INSERT INTO companies (name, business_type, currency, entitlement_type)
         VALUES ('Modiri Administration', 'company', 'DZD', 'lifetime')
         RETURNING id`,
      );
      adminCompId = newComp.rows[0].id;
    }

    // Setup tenant test company
    const tenantComp = await query(
      `INSERT INTO companies (name, business_type, currency, entitlement_type)
       VALUES ('Tenant Co for Admin Test', 'grocery', 'DZD', 'trial')
       RETURNING id`,
    );
    testCompanyId = tenantComp.rows[0].id;

    // Hash admin password
    const pwHash = await bcrypt.hash(adminPassword, 10);

    // 3. Create Super Admin user
    const saRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Main Super Admin', 'test.superadmin@modiri.ai', $2, 'super_admin', true)
       RETURNING id`,
      [adminCompId, pwHash],
    );
    superAdminId = saRes.rows[0].id;

    // 4. Create Support Desk user
    const supRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Support Agent', 'test.support@modiri.ai', $2, 'support', true)
       RETURNING id`,
      [adminCompId, pwHash],
    );
    supportUserId = supRes.rows[0].id;

    // 5. Create Regular Business Owner user
    const regRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Business Owner', 'regular.owner@tenant.modiri.ai', $2, 'owner', true)
       RETURNING id`,
      [testCompanyId, pwHash],
    );
    regularUserId = regRes.rows[0].id;

    // Sign JWT tokens
    superAdminToken = jwt.sign(
      { sub: superAdminId, role: 'super_admin', companyId: adminCompId, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );
    supportToken = jwt.sign(
      { sub: supportUserId, role: 'support', companyId: adminCompId, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );
    regularUserToken = jwt.sign(
      { sub: regularUserId, role: 'owner', companyId: testCompanyId, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );
  });

  afterAll(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    try {
      await query(`DELETE FROM users WHERE id IN ($1, $2, $3)`, [
        superAdminId,
        supportUserId,
        regularUserId,
      ]);
      await query(`DELETE FROM companies WHERE id = $1`, [testCompanyId]);
    } catch (_) {}
  });

  describe('1. Dashboard HTML SPA Delivery', () => {
    test('GET /admin returns HTTP 200 and serves HTML dashboard', async () => {
      const res = await fetch(`${baseUrl}/admin`);
      expect(res.status).toBe(200);
      const text = await res.text();
      expect(text).toContain('<!DOCTYPE html>');
      expect(text).toContain('Modiri AI');
      expect(text).toContain('Admin Portal');
    });

    test('GET /admin/ (trailing slash) returns HTTP 200 and serves HTML dashboard', async () => {
      const res = await fetch(`${baseUrl}/admin/`);
      expect(res.status).toBe(200);
      const text = await res.text();
      expect(text).toContain('<!DOCTYPE html>');
      expect(text).toContain('Admin Portal');
    });

    test('GET /admin/users (SPA client subpath) returns HTTP 200 with dashboard HTML', async () => {
      const res = await fetch(`${baseUrl}/admin/users`);
      expect(res.status).toBe(200);
      const text = await res.text();
      expect(text).toContain('<!DOCTYPE html>');
    });
  });

  describe('2. Admin Dedicated Login (/api/admin/auth/login)', () => {
    test('rejects login with incorrect password', async () => {
      const res = await fetch(`${baseUrl}/api/admin/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'test.superadmin@modiri.ai',
          password: 'WrongPassword999!',
        }),
      });
      expect(res.status).toBe(401);
      const json = await res.json();
      expect(json.message).toMatch(/Invalid email or password/i);
    });

    test('rejects login for regular business owner (defense against non-admin login)', async () => {
      const res = await fetch(`${baseUrl}/api/admin/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'regular.owner@tenant.modiri.ai',
          password: adminPassword,
        }),
      });
      expect(res.status).toBe(403);
      const json = await res.json();
      expect(json.message).toMatch(/Administrative privileges required/i);
    });

    test('accepts login for valid Super Admin and returns accessToken', async () => {
      const res = await fetch(`${baseUrl}/api/admin/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'test.superadmin@modiri.ai',
          password: adminPassword,
        }),
      });
      expect(res.status).toBe(200);
      const json = await res.json();
      expect(json.data.accessToken).toBeDefined();
      expect(json.data.admin.role).toBe('super_admin');
    });
  });

  describe('3. Privileged API Server-Side Authorization', () => {
    test('GET /api/admin/overview without token returns 401 Unauthorized', async () => {
      const res = await fetch(`${baseUrl}/api/admin/overview`);
      expect(res.status).toBe(401);
      const json = await res.json();
      expect(json.message).toMatch(/Missing or malformed Authorization header/i);
    });

    test('GET /api/admin/overview with regular owner token returns 403 Forbidden', async () => {
      const res = await fetch(`${baseUrl}/api/admin/overview`, {
        headers: { Authorization: `Bearer ${regularUserToken}` },
      });
      expect(res.status).toBe(403);
      const json = await res.json();
      expect(json.message).toMatch(/Insufficient permissions/i);
    });

    test('GET /api/admin/overview with support token succeeds (HTTP 200)', async () => {
      const res = await fetch(`${baseUrl}/api/admin/overview`, {
        headers: { Authorization: `Bearer ${supportToken}` },
      });
      expect(res.status).toBe(200);
      const json = await res.json();
      expect(json.data.totalAccounts).toBeDefined();
    });

    test('GET /api/admin/overview with super_admin token succeeds (HTTP 200)', async () => {
      const res = await fetch(`${baseUrl}/api/admin/overview`, {
        headers: { Authorization: `Bearer ${superAdminToken}` },
      });
      expect(res.status).toBe(200);
      const json = await res.json();
      expect(json.data.totalAccounts).toBeDefined();
      expect(json.data.activeTrials).toBeDefined();
    });

    test('POST /api/admin/users/:id/grant-lifetime with support token returns 403 (super_admin only)', async () => {
      const res = await fetch(`${baseUrl}/api/admin/users/${testCompanyId}/grant-lifetime`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${supportToken}`,
        },
        body: JSON.stringify({ reason: 'Unauthorized attempt by support' }),
      });
      expect(res.status).toBe(403);
      const json = await res.json();
      expect(json.message).toMatch(/Insufficient permissions/i);
    });

    test('POST /api/admin/users/:id/grant-lifetime with super_admin token succeeds', async () => {
      const res = await fetch(`${baseUrl}/api/admin/users/${testCompanyId}/grant-lifetime`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${superAdminToken}`,
        },
        body: JSON.stringify({ reason: 'Granted by super_admin during test' }),
      });
      expect(res.status).toBe(200);
      const json = await res.json();
      expect(json.data.entitlementType).toBe('lifetime');

      // Verify in DB
      const check = await query(`SELECT entitlement_type FROM companies WHERE id = $1`, [
        testCompanyId,
      ]);
      expect(check.rows[0].entitlement_type).toBe('lifetime');
    });
  });
});

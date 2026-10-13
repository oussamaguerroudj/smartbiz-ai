const http = require('http');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../config/db');
const env = require('../config/env');
const app = require('../app');
const { resetRateLimiters } = require('../middlewares/rateLimit.middleware');

describe('Account Suspension, Instant Lockout, Scoped Appeals & Trial Expiration Enforcement Suite', () => {
  let server;
  let baseUrl;

  let adminCompanyId;
  let superAdminId;
  let superAdminToken;

  let companyAId;
  let userAId;
  let userAToken;
  let userARefreshToken;

  let companyBId;
  let userBId;
  let userBToken;

  const testPassword = 'TestPassword123!';

  beforeAll(async () => {
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}`;

    const pwHash = await bcrypt.hash(testPassword, 10);

    // 1. Create Admin Company & Super Admin
    const adminCompRes = await query(
      `INSERT INTO companies (name, business_type, currency, onboarding_completed, entitlement_type, account_approval_status)
       VALUES ('Modiri Admin HQ', 'company', 'DZD', true, 'lifetime', 'approved')
       RETURNING id`,
    );
    adminCompanyId = adminCompRes.rows[0].id;

    const saRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Chief Super Admin', 'sa.enforcement@test.modiri.ai', $2, 'super_admin', true)
       RETURNING id`,
      [adminCompanyId, pwHash],
    );
    superAdminId = saRes.rows[0].id;
    superAdminToken = jwt.sign(
      { sub: superAdminId, companyId: adminCompanyId, role: 'super_admin', type: 'access' },
      env.jwt.accessSecret,
      { algorithm: 'HS256', expiresIn: '2h' },
    );

    // 2. Create Tenant A (Active Trial initially)
    const futureTrialEnd = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000);
    const compARes = await query(
      `INSERT INTO companies (name, business_type, currency, onboarding_completed, entitlement_type, trial_starts_at, trial_ends_at, account_approval_status, is_suspended)
       VALUES ('Atlas Grocery A', 'grocery', 'DZD', true, 'trial', now(), $1, 'approved', false)
       RETURNING id`,
      [futureTrialEnd],
    );
    companyAId = compARes.rows[0].id;

    const uARes = await query(
      `INSERT INTO users (company_id, name, email, phone, password_hash, role, email_verified)
       VALUES ($1, 'Karim Atlas', 'karim.atlas@test.modiri.ai', '0550112233', $2, 'owner', true)
       RETURNING id`,
      [companyAId, pwHash],
    );
    userAId = uARes.rows[0].id;

    userAToken = jwt.sign(
      { sub: userAId, companyId: companyAId, role: 'owner', type: 'access' },
      env.jwt.accessSecret,
      { algorithm: 'HS256', expiresIn: '1h' },
    );
    userARefreshToken = jwt.sign(
      { sub: userAId, companyId: companyAId, role: 'owner', type: 'refresh' },
      env.jwt.refreshSecret,
      { algorithm: 'HS256', expiresIn: '7d' },
    );

    // 3. Create Tenant B (Separate tenant for isolation & trial expiry tests)
    const compBRes = await query(
      `INSERT INTO companies (name, business_type, currency, onboarding_completed, entitlement_type, trial_starts_at, trial_ends_at, account_approval_status, is_suspended)
       VALUES ('Sahara Pharmacy B', 'pharmacy', 'DZD', true, 'trial', now(), $1, 'approved', false)
       RETURNING id`,
      [futureTrialEnd],
    );
    companyBId = compBRes.rows[0].id;

    const uBRes = await query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Amina Sahara', 'amina.sahara@test.modiri.ai', $2, 'owner', true)
       RETURNING id`,
      [companyBId, pwHash],
    );
    userBId = uBRes.rows[0].id;
    userBToken = jwt.sign(
      { sub: userBId, companyId: companyBId, role: 'owner', type: 'access' },
      env.jwt.accessSecret,
      { algorithm: 'HS256', expiresIn: '1h' },
    );
  });

  beforeEach(() => {
    resetRateLimiters();
  });

  afterAll(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    try {
      await query('DELETE FROM manual_payment_requests WHERE company_id IN ($1, $2)', [companyAId, companyBId]);
      await query('DELETE FROM payment_orders WHERE company_id IN ($1, $2)', [companyAId, companyBId]);
      await query('DELETE FROM notifications WHERE company_id IN ($1, $2)', [companyAId, companyBId]);
      await query('DELETE FROM support_messages WHERE company_id IN ($1, $2)', [companyAId, companyBId]);
      await query('DELETE FROM license_audit_logs WHERE company_id IN ($1, $2)', [companyAId, companyBId]);
      await query('DELETE FROM products WHERE company_id IN ($1, $2)', [companyAId, companyBId]);
      await query('DELETE FROM users WHERE id IN ($1, $2, $3)', [superAdminId, userAId, userBId]);
      await query('DELETE FROM companies WHERE id IN ($1, $2, $3)', [adminCompanyId, companyAId, companyBId]);
    } catch (_) {}
  });

  describe('1. Active Account Baseline & Instant Mid-Session Suspension Enforcement', () => {
    let capturedAppealToken = null;

    test('Active user can create and read business data before suspension', async () => {
      const createRes = await fetch(`${baseUrl}/api/products`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${userAToken}`,
        },
        body: JSON.stringify({
          name: 'Olive Oil 1L',
          purchasePrice: 600,
          sellingPrice: 850,
          quantity: 40,
        }),
      });
      expect(createRes.status).toBe(201);

      const listRes = await fetch(`${baseUrl}/api/products`, {
        headers: { Authorization: `Bearer ${userAToken}` },
      });
      expect(listRes.status).toBe(200);
      const listJson = await listRes.json();
      expect(listJson.data.length).toBe(1);
    });

    test('Super Admin requires a reason/message when suspending an account', async () => {
      const badRes = await fetch(`${baseUrl}/api/admin/users/${companyAId}/suspend`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${superAdminToken}`,
        },
        body: JSON.stringify({
          isSuspended: true,
          reason: '',
        }),
      });
      expect(badRes.status).toBe(400);
      const badJson = await badRes.json();
      expect(badJson.code).toBe('SUSPENSION_REASON_REQUIRED');
    });

    test('Super Admin suspends Tenant A with a clear message and records audit log', async () => {
      const suspendRes = await fetch(`${baseUrl}/api/admin/users/${companyAId}/suspend`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${superAdminToken}`,
        },
        body: JSON.stringify({
          isSuspended: true,
          message: 'Account suspended due to unverified payment receipt #9941. Please submit an appeal with clarification.',
        }),
      });
      expect(suspendRes.status).toBe(200);
      const suspendJson = await suspendRes.json();
      expect(suspendJson.data.isSuspended).toBe(true);
      expect(suspendJson.data.suspensionReason).toContain('unverified payment receipt #9941');
      expect(suspendJson.data.suspendedAt).toBeTruthy();
    });

    test('Existing valid JWT is immediately rejected with 403 ACCOUNT_SUSPENDED on protected business endpoints', async () => {
      const endpoints = [
        { method: 'GET', path: '/api/products' },
        { method: 'POST', path: '/api/products', body: { name: 'Blocked Item', purchasePrice: 10, sellingPrice: 20, quantity: 1 } },
        { method: 'GET', path: '/api/sales' },
        { method: 'GET', path: '/api/invoices' },
        { method: 'GET', path: '/api/expenses' },
        { method: 'GET', path: '/api/customers' },
        { method: 'GET', path: '/api/reports/summary' },
        { method: 'GET', path: '/api/dashboard' },
        { method: 'GET', path: '/api/companies/me' },
        { method: 'GET', path: '/api/auth/profile' },
        { method: 'GET', path: '/api/subscriptions/status' },
      ];

      for (const ep of endpoints) {
        const res = await fetch(`${baseUrl}${ep.path}`, {
          method: ep.method,
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${userAToken}`,
          },
          body: ep.body ? JSON.stringify(ep.body) : undefined,
        });
        expect(res.status).toBe(403);
        const body = await res.json();
        expect(body.code).toBe('ACCOUNT_SUSPENDED');
        expect(body.details).toBeDefined();
        expect(body.details.isSuspended).toBe(true);
        expect(body.details.suspensionReason).toContain('unverified payment receipt #9941');
        expect(body.details.appealToken).toBeTruthy();
        capturedAppealToken = body.details.appealToken;
      }
    });

    test('Suspended account cannot upload or pull sync batches (/api/sync)', async () => {
      const syncRes = await fetch(`${baseUrl}/api/sync/push`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${userAToken}`,
        },
        body: JSON.stringify({ operations: [] }),
      });
      expect(syncRes.status).toBe(403);
      const syncJson = await syncRes.json();
      expect(syncJson.code).toBe('ACCOUNT_SUSPENDED');
    });

    test('Suspended account cannot refresh session via POST /api/auth/refresh', async () => {
      const refRes = await fetch(`${baseUrl}/api/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: userARefreshToken }),
      });
      expect(refRes.status).toBe(403);
      const refJson = await refRes.json();
      expect(refJson.code).toBe('ACCOUNT_SUSPENDED');
      expect(refJson.accessToken).toBeUndefined();
      expect(refJson.refreshToken).toBeUndefined();
      expect(refJson.details.appealToken).toBeTruthy();
    });

    test('Suspended account login attempt via POST /api/auth/login returns 403 ACCOUNT_SUSPENDED without issuing access/refresh tokens', async () => {
      const loginRes = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'karim.atlas@test.modiri.ai',
          password: testPassword,
        }),
      });
      expect(loginRes.status).toBe(403);
      const loginJson = await loginRes.json();
      expect(loginJson.code).toBe('ACCOUNT_SUSPENDED');
      expect(loginJson.accessToken).toBeUndefined();
      expect(loginJson.refreshToken).toBeUndefined();
      expect(loginJson.details.suspensionReason).toContain('unverified payment receipt #9941');
      expect(loginJson.details.appealToken).toBeTruthy();
      expect(loginJson.details.user.id).toBe(userAId);
      expect(loginJson.details.company.id).toBe(companyAId);
    });

    test('Narrowly scoped appealToken is rejected with 401 on all business and refresh endpoints', async () => {
      expect(capturedAppealToken).toBeTruthy();

      const prodRes = await fetch(`${baseUrl}/api/products`, {
        headers: { Authorization: `Bearer ${capturedAppealToken}` },
      });
      expect(prodRes.status).toBe(401);

      const compRes = await fetch(`${baseUrl}/api/companies/me`, {
        headers: { Authorization: `Bearer ${capturedAppealToken}` },
      });
      expect(compRes.status).toBe(401);

      const refRes = await fetch(`${baseUrl}/api/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: capturedAppealToken }),
      });
      expect(refRes.status).toBe(401);
    });

    describe('2. User Appeal Submission, Validation & Admin Review Workflow', () => {
      let submittedAppealId = null;
      let submittedTicketNumber = null;

      test('Unauthenticated appeal submission is rejected with 401 APPEAL_AUTH_REQUIRED', async () => {
        const res = await fetch(`${baseUrl}/api/support/appeal`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: 'Please unsuspend my account without a token.',
          }),
        });
        expect(res.status).toBe(401);
        const json = await res.json();
        expect(json.code).toBe('APPEAL_AUTH_REQUIRED');
      });

      test('Appeal submission validates minimum length (>= 10 characters)', async () => {
        const res = await fetch(`${baseUrl}/api/support/appeal`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${capturedAppealToken}`,
          },
          body: JSON.stringify({
            message: 'Too short',
          }),
        });
        expect(res.status).toBe(400);
        const json = await res.json();
        expect(json.code).toBe('VALIDATION_ERROR');
      });

      test('Suspended user submits a valid appeal and server binds identity strictly from DB (ignoring spoofed body fields)', async () => {
        const res = await fetch(`${baseUrl}/api/support/appeal`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${capturedAppealToken}`,
          },
          body: JSON.stringify({
            // Attempt to spoof another companyId/userId in body
            companyId: companyBId,
            userId: userBId,
            email: 'spoofed@attacker.com',
            subject: 'Clarification on Receipt #9941',
            message: 'Hello Admin, the CCP transfer was sent from my spouse account. I have the original stamped post office receipt ready.',
            contactPhone: '0550998877',
          }),
        });

        expect(res.status).toBe(201);
        const json = await res.json();
        expect(json.data.appealId).toBeDefined();
        expect(json.data.ticketNumber).toMatch(/^APL-/);
        expect(json.data.status).toBe('new');
        submittedAppealId = json.data.appealId;
        submittedTicketNumber = json.data.ticketNumber;

        // Verify in DB that company_id and user_id are strictly Tenant A, never spoofed Tenant B
        const dbAppeal = await query('SELECT * FROM support_messages WHERE id = $1', [submittedAppealId]);
        expect(dbAppeal.rows[0].company_id).toBe(companyAId);
        expect(dbAppeal.rows[0].user_id).toBe(userAId);
        expect(dbAppeal.rows[0].email).toBe('karim.atlas@test.modiri.ai');
        expect(dbAppeal.rows[0].category).toBe('suspension_appeal');
      });

      test('Suspended user can check appeal status via GET /api/support/appeal/status', async () => {
        const res = await fetch(`${baseUrl}/api/support/appeal/status`, {
          headers: { Authorization: `Bearer ${capturedAppealToken}` },
        });
        expect(res.status).toBe(200);
        const json = await res.json();
        expect(json.data.isSuspended).toBe(true);
        expect(json.data.companyId).toBe(companyAId);
        expect(json.data.appeals.length).toBe(1);
        expect(json.data.appeals[0].ticketNumber).toBe(submittedTicketNumber);
      });

      test('Super Admin can view suspension appeals in dashboard, record internal note and post user-facing public reply', async () => {
        const listRes = await fetch(`${baseUrl}/api/admin/support?category=suspension_appeal&status=new`, {
          headers: { Authorization: `Bearer ${superAdminToken}` },
        });
        expect(listRes.status).toBe(200);
        const listJson = await listRes.json();
        const found = listJson.data.find((m) => m.id === submittedAppealId);
        expect(found).toBeDefined();
        expect(found.company_name).toBe('Atlas Grocery A');
        expect(found.company_is_suspended).toBe(true);

        const updateRes = await fetch(`${baseUrl}/api/admin/support/${submittedAppealId}/status`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${superAdminToken}`,
          },
          body: JSON.stringify({
            status: 'in_progress',
            adminNotes: 'INTERNAL_CONFIDENTIAL_INVESTIGATION_NOTE: High risk IP mismatch, cross-check bank records.',
            publicReply: 'Your appeal is in progress. Please provide a clear scan of the postal money order.',
          }),
        });
        expect(updateRes.status).toBe(200);
      });

      test('Suspended user receives user-facing publicReply while internal admin notes and privileged metadata are strictly redacted', async () => {
        const res = await fetch(`${baseUrl}/api/support/appeal/status`, {
          headers: { Authorization: `Bearer ${capturedAppealToken}` },
        });
        expect(res.status).toBe(200);
        const rawBody = await res.text();
        const json = JSON.parse(rawBody);

        expect(json.data.appeals.length).toBe(1);
        const appeal = json.data.appeals[0];

        // 1. User sees the public reply
        expect(appeal.publicReply).toBe('Your appeal is in progress. Please provide a clear scan of the postal money order.');
        expect(appeal.status).toBe('in_progress');

        // 2. Internal admin notes must NOT be in the object
        expect(appeal.adminNotes).toBeUndefined();
        expect(appeal.admin_notes).toBeUndefined();

        // 3. Complete text check: confidential internal terms must never leak into raw response
        expect(rawBody).not.toContain('INTERNAL_CONFIDENTIAL_INVESTIGATION_NOTE');
        expect(rawBody).not.toContain('IP mismatch');
        expect(rawBody).not.toContain('bank records');
      });

      test('Super Admin reactivates (unsuspends) Tenant A -> open appeals marked answered & user regains full access', async () => {
        const restoreRes = await fetch(`${baseUrl}/api/admin/users/${companyAId}/suspend`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${superAdminToken}`,
          },
          body: JSON.stringify({
            isSuspended: false,
            message: 'Receipt verified and account restored.',
          }),
        });
        expect(restoreRes.status).toBe(200);
        const restoreJson = await restoreRes.json();
        expect(restoreJson.data.isSuspended).toBe(false);

        // Verify appeal status now reflects unsuspended and status='answered'
        const statusRes = await fetch(`${baseUrl}/api/support/appeal/status`, {
          headers: { Authorization: `Bearer ${capturedAppealToken}` },
        });
        expect(statusRes.status).toBe(200);
        const statusJson = await statusRes.json();
        expect(statusJson.data.isSuspended).toBe(false);
        expect(statusJson.data.appeals[0].status).toBe('answered');

        // Verify Tenant A can log in again and access preserved business data
        const loginRes = await fetch(`${baseUrl}/api/auth/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email: 'karim.atlas@test.modiri.ai',
            password: testPassword,
          }),
        });
        expect(loginRes.status).toBe(200);
        const loginJson = await loginRes.json();
        expect(loginJson.accessToken).toBeTruthy();

        const prodRes = await fetch(`${baseUrl}/api/products`, {
          headers: { Authorization: `Bearer ${loginJson.accessToken}` },
        });
        expect(prodRes.status).toBe(200);
        const prodJson = await prodRes.json();
        expect(prodJson.data.length).toBe(1);
        expect(prodJson.data[0].name).toBe('Olive Oil 1L');
      });
    });
  });

  describe('3. Trial Expiration & Temporary License Expiration Enforcement', () => {
    test('When Tenant B trial expires, business endpoints and sync are blocked with 403 TRIAL_EXPIRED while renewal endpoints remain open', async () => {
      // Expire Tenant B's trial in PostgreSQL
      const pastStart = new Date(Date.now() - 16 * 24 * 60 * 60 * 1000);
      const pastEnd = new Date(Date.now() - 1 * 24 * 60 * 60 * 1000);
      await query(
        `UPDATE companies
         SET entitlement_type = 'trial',
             trial_starts_at = $2,
             trial_ends_at = $3
         WHERE id = $1`,
        [companyBId, pastStart, pastEnd],
      );

      // 1. Business endpoints MUST be blocked with 403 TRIAL_EXPIRED
      const blockedEndpoints = [
        { method: 'GET', path: '/api/products' },
        { method: 'POST', path: '/api/products', body: { name: 'Aspirin', purchasePrice: 100, sellingPrice: 150, quantity: 10 } },
        { method: 'GET', path: '/api/sales' },
        { method: 'GET', path: '/api/customers' },
        { method: 'GET', path: '/api/dashboard' },
        { method: 'POST', path: '/api/sync/push', body: { operations: [] } },
      ];

      for (const ep of blockedEndpoints) {
        const res = await fetch(`${baseUrl}${ep.path}`, {
          method: ep.method,
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${userBToken}`,
          },
          body: ep.body ? JSON.stringify(ep.body) : undefined,
        });
        expect(res.status).toBe(403);
        const body = await res.json();
        expect(body.code).toBe('TRIAL_EXPIRED');
        expect(body.details).toBeDefined();
        expect(body.details.accountStatus).toBe('expired_trial');
        expect(body.details.product.price).toBe(15000);
      }

      // 2. Attempting to re-select free trial when expired MUST be rejected with 403 TRIAL_EXPIRED
      const restartTrialRes = await fetch(`${baseUrl}/api/subscriptions/select-trial`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(restartTrialRes.status).toBe(403);
      const restartTrialJson = await restartTrialRes.json();
      expect(restartTrialJson.code).toBe('TRIAL_EXPIRED');

      // 3. Allowed renewal/status endpoints MUST succeed so user can upgrade from TrialExpiredScreen
      const statusRes = await fetch(`${baseUrl}/api/subscriptions/status`, {
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(statusRes.status).toBe(200);
      const statusJson = await statusRes.json();
      expect(statusJson.data.status).toBe('expired_trial');
      expect(statusJson.data.hasAccess).toBe(false);

      const manualPayRes = await fetch(`${baseUrl}/api/payments/manual-request`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${userBToken}`,
        },
        body: JSON.stringify({ transferReference: 'CCP-RENEW-7788' }),
      });
      expect(manualPayRes.status).toBe(200);
    });

    test('Expired temporary license also blocks business endpoints with 403 TRIAL_EXPIRED (accountStatus: expired_temporary)', async () => {
      const pastLicenseEnd = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000);
      await query(
        `UPDATE companies
         SET entitlement_type = 'temporary',
             license_expires_at = $2
         WHERE id = $1`,
        [companyBId, pastLicenseEnd],
      );

      const prodRes = await fetch(`${baseUrl}/api/products`, {
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(prodRes.status).toBe(403);
      const prodJson = await prodRes.json();
      expect(prodJson.code).toBe('TRIAL_EXPIRED');
      expect(prodJson.details.accountStatus).toBe('expired_temporary');
    });

    test('Granting lifetime license to expired Tenant B immediately restores full business access', async () => {
      const grantRes = await fetch(`${baseUrl}/api/admin/users/${companyBId}/grant-lifetime`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${superAdminToken}`,
        },
        body: JSON.stringify({ reason: 'Paid lifetime license after trial expiry' }),
      });
      expect(grantRes.status).toBe(200);

      const prodRes = await fetch(`${baseUrl}/api/products`, {
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(prodRes.status).toBe(200);
    });

    test('Soft-deleted user with unexpired JWT is immediately rejected with 401 SESSION_REVOKED', async () => {
      await query('UPDATE users SET deleted_at = now() WHERE id = $1', [userBId]);

      const prodRes = await fetch(`${baseUrl}/api/products`, {
        headers: { Authorization: `Bearer ${userBToken}` },
      });
      expect(prodRes.status).toBe(401);
      const prodJson = await prodRes.json();
      expect(prodJson.code).toBe('SESSION_REVOKED');

      // Restore deleted_at = null for clean teardown
      await query('UPDATE users SET deleted_at = NULL WHERE id = $1', [userBId]);
    });
  });
});


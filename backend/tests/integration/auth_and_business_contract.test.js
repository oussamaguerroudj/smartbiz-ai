// backend/tests/integration/auth_and_business_contract.test.js
// 
// Phase 3 Integration Tests against REAL PostgreSQL instance (no jest.mock of config/db).
// Tests contract requirements:
// 1. POST /api/auth/register {name, email, password} creates pending registration only without industry/type.
// 2. Email uniqueness enforced with normalized casing and whitespace (lower(trim(email))).
// 3. Duplicate registration gives correct conflict status without leaking password matches on unverified accounts.
// 4. Account verification (verifyEmail) does NOT prematurely create a dummy company with business_type='company'.
// 5. Incomplete onboarding state is explicitly communicated by the API.
// 6. Business type persistence to company record, routing verification, rejection of invalid types (e.g. 'construction').

process.env.NODE_ENV = 'test';
process.env.PORT = '4099';
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

describe('Auth & Business Onboarding Integration Suite (Real PostgreSQL)', () => {
  let server;
  let baseUrl;
  let testPool;

  beforeAll(async () => {
    testPool = new Pool({
      connectionString: process.env.DATABASE_URL,
    });

    // Start Express app on ephemeral port
    await new Promise((resolve) => {
      server = app.listen(0, '127.0.0.1', () => {
        const port = server.address().port;
        baseUrl = `http://127.0.0.1:${port}/api`;
        resolve();
      });
    });
  });

  afterAll(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    if (testPool) {
      await testPool.end();
    }
    const { pool } = require('../../src/config/db');
    if (pool) {
      await pool.end();
    }
  });

  beforeEach(async () => {
    // Clean test tables before each test
    await testPool.query('DELETE FROM pending_registrations');
    await testPool.query('DELETE FROM users');
    await testPool.query('DELETE FROM companies');
  });

  test('1. Registration succeeds with ONLY {name, email, password} and requires NO industry or type', async () => {
    const res = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Tarek Business',
        email: 'tarek@example.com',
        password: 'Password123!',
      }),
    });

    const body = await res.json();
    // Intended contract: must succeed with 201 Created on the first attempt without industry/type
    expect(res.status).toBe(201);
    expect(body.email).toBe('tarek@example.com');
    expect(body.pendingVerification).toBe(true);

    // Verify database: only pending_registrations has record, users and companies remain empty
    const pending = await testPool.query('SELECT * FROM pending_registrations WHERE email = $1', ['tarek@example.com']);
    expect(pending.rows.length).toBe(1);
    expect(pending.rows[0].name).toBe('Tarek Business');

    const users = await testPool.query('SELECT * FROM users');
    expect(users.rows.length).toBe(0);

    const companies = await testPool.query('SELECT * FROM companies');
    expect(companies.rows.length).toBe(0);
  });

  test('2. Email uniqueness is strictly enforced against casing and whitespace variations (normalized lower(trim(email)))', async () => {
    // Insert a verified user with lower-cased email
    const compRes = await testPool.query(
      `INSERT INTO companies (name, business_type, currency) VALUES ('Initial Co', 'grocery', 'DZD') RETURNING id`,
    );
    const companyId = compRes.rows[0].id;
    await testPool.query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Original User', 'user@example.com', 'dummy_hash', 'owner', true)`,
      [companyId],
    );

    // Attempting to register with variation "  User@Example.COM  " must be identified as conflict
    const res = await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Imposter User',
        email: '  User@Example.COM  ',
        password: 'Password123!',
      }),
    });

    expect(res.status).toBe(409);
    const body = await res.json();
    expect(body.code).toBe('EMAIL_TAKEN');

    // Database test: directly testing whether database uniqueness constraint prevents insert of casing duplicate
    await expect(
      testPool.query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Duplicate User', 'USER@EXAMPLE.COM', 'dummy_hash', 'owner', true)`,
        [companyId],
      ),
    ).rejects.toThrow();
  });

  test('3. Unverified pending registration returns intentional 403 EMAIL_NOT_VERIFIED on correct credentials and 401 on incorrect credentials', async () => {
    // User registers but has not verified email yet
    await fetch(`${baseUrl}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Pending User',
        email: 'pending@example.com',
        password: 'CorrectSecretPassword123!',
      }),
    });

    // Login attempt with correct password returns intentional 403 EMAIL_NOT_VERIFIED
    const correctRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'pending@example.com',
        password: 'CorrectSecretPassword123!',
      }),
    });
    expect(correctRes.status).toBe(403);
    const correctBody = await correctRes.json();
    expect(correctBody.code).toBe('EMAIL_NOT_VERIFIED');

    // Login attempt with wrong password returns 401 INVALID_CREDENTIALS
    const wrongRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'pending@example.com',
        password: 'WrongPassword999!',
      }),
    });
    expect(wrongRes.status).toBe(401);
    const wrongBody = await wrongRes.json();
    expect(wrongBody.code).toBe('INVALID_CREDENTIALS');
  });

  test('4. verifyEmail creates company with business_type=NULL and onboardingCompleted=false (Option A)', async () => {
    // 1. Create a pending registration directly
    const expires = new Date(Date.now() + 60000);
    const { hashCode } = require('../../src/utils/otp');
    const bcrypt = require('bcrypt');
    const passwordHash = await bcrypt.hash('Password123!', 10);
    const codeHash = hashCode('123456');

    await testPool.query(
      `INSERT INTO pending_registrations (name, email, password_hash, code_hash, code_expires, attempts)
       VALUES ('New Founder', 'founder@example.com', $1, $2, $3, 0)`,
      [passwordHash, codeHash, expires],
    );

    // 2. Confirm verification code
    const res = await fetch(`${baseUrl}/auth/verify-email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'founder@example.com',
        code: '123456',
      }),
    });

    expect(res.status).toBe(200);
    const body = await res.json();

    // Option A architectural requirements:
    expect(body.user.businessType).toBeNull();
    expect(body.user.onboardingCompleted).toBe(false);
    expect(body.company).toBeDefined();
    expect(body.company.businessType).toBeNull();
    expect(body.company.onboardingCompleted).toBe(false);
  });

  test('5. Business setup persists selected Grocery/Superette type, completes onboarding, and rejects invalid types like "construction"', async () => {
    // Set up a verified owner with pending business type (null)
    const compRes = await testPool.query(
      `INSERT INTO companies (name, business_type, onboarding_completed, currency) VALUES ('Pending Setup', NULL, false, 'DZD') RETURNING id`,
    );
    const companyId = compRes.rows[0].id;

    const userRes = await testPool.query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Store Owner', 'owner@market.dz', 'dummy_hash', 'owner', true)
       RETURNING id`,
      [companyId],
    );
    const userId = userRes.rows[0].id;

    const jwt = require('jsonwebtoken');
    const env = require('../../src/config/env');
    const token = jwt.sign(
      { sub: userId, companyId, role: 'owner', emailVerified: true, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );

    // A. Rejects invalid type 'construction' (which is an industry but NOT a valid backend business_type_enum)
    const invalidRes = await fetch(`${baseUrl}/companies/me`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        businessType: 'construction',
      }),
    });
    expect(invalidRes.status).toBe(400);

    // B. Successfully persists 'grocery' and marks onboardingCompleted=true
    const validRes = await fetch(`${baseUrl}/companies/me`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        name: 'El-Amel Superette',
        businessType: 'grocery',
      }),
    });

    expect(validRes.status).toBe(200);
    const validBody = await validRes.json();
    expect(validBody.data.businessType).toBe('grocery');
    expect(validBody.data.onboardingCompleted).toBe(true);

    // C. Verify persisted in PostgreSQL
    const checkDb = await testPool.query('SELECT business_type, onboarding_completed, name FROM companies WHERE id = $1', [companyId]);
    expect(checkDb.rows[0].business_type).toBe('grocery');
    expect(checkDb.rows[0].onboarding_completed).toBe(true);
    expect(checkDb.rows[0].name).toBe('El-Amel Superette');
  });

  test('6. Null business_type cleanly blocks specialized modules with 403 (never 500)', async () => {
    // Create company with NULL business_type and uncompleted onboarding
    const compRes = await testPool.query(
      `INSERT INTO companies (name, business_type, onboarding_completed, currency) VALUES ('Incomplete Co', NULL, false, 'DZD') RETURNING id`,
    );
    const companyId = compRes.rows[0].id;

    const userRes = await testPool.query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Onboarding User', 'incomplete@user.dz', 'dummy_hash', 'owner', true)
       RETURNING id`,
      [companyId],
    );
    const userId = userRes.rows[0].id;

    const jwt = require('jsonwebtoken');
    const env = require('../../src/config/env');
    const token = jwt.sign(
      { sub: userId, companyId, role: 'owner', emailVerified: true, type: 'access' },
      env.jwt.accessSecret,
      { expiresIn: '1h' },
    );

    const endpoints = [
      '/superette/categories',
      '/clinic/patients',
      '/restaurant/menu-items',
      '/pharmacy/medicines',
      '/clothing/items',
      '/enterprise/projects',
    ];

    for (const ep of endpoints) {
      const res = await fetch(`${baseUrl}${ep}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(res.status).toBe(403);
      const data = await res.json();
      expect(data.code).toBe('BUSINESS_TYPE_NOT_ALLOWED');
    }
  });

  test('7. Login, refresh, and /companies/me all return onboardingCompleted and businessType in identical format', async () => {
    // Verified user with completed onboarding
    const bcrypt = require('bcrypt');
    const hash = await bcrypt.hash('Secret12345!', 10);
    const compRes = await testPool.query(
      `INSERT INTO companies (name, business_type, onboarding_completed, currency) VALUES ('Verified Co', 'pharmacy', true, 'DZD') RETURNING id`,
    );
    const companyId = compRes.rows[0].id;

    const userRes = await testPool.query(
      `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
       VALUES ($1, 'Pharma User', 'pharma@test.dz', $2, 'owner', true)
       RETURNING id`,
      [companyId, hash],
    );
    const userId = userRes.rows[0].id;

    // A. Login
    const loginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'pharma@test.dz', password: 'Secret12345!' }),
    });
    expect(loginRes.status).toBe(200);
    const loginBody = await loginRes.json();
    expect(loginBody.user.businessType).toBe('pharmacy');
    expect(loginBody.user.onboardingCompleted).toBe(true);
    expect(loginBody.company.businessType).toBe('pharmacy');
    expect(loginBody.company.onboardingCompleted).toBe(true);

    // B. Refresh
    const refreshRes = await fetch(`${baseUrl}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: loginBody.refreshToken }),
    });
    expect(refreshRes.status).toBe(200);
    const refreshBody = await refreshRes.json();
    expect(refreshBody.user.businessType).toBe('pharmacy');
    expect(refreshBody.user.onboardingCompleted).toBe(true);
    expect(refreshBody.company.businessType).toBe('pharmacy');
    expect(refreshBody.company.onboardingCompleted).toBe(true);

    // C. Companies/me
    const meRes = await fetch(`${baseUrl}/companies/me`, {
      headers: { Authorization: `Bearer ${loginBody.accessToken}` },
    });
    expect(meRes.status).toBe(200);
    const meBody = await meRes.json();
    expect(meBody.data.businessType).toBe('pharmacy');
    expect(meBody.data.onboardingCompleted).toBe(true);
  });
});

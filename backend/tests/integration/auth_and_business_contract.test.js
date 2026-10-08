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

  test('3. Unverified pending registration does NOT leak password match during login', async () => {
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

    // Login attempt with correct password
    const correctRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'pending@example.com',
        password: 'CorrectSecretPassword123!',
      }),
    });

    // Login attempt with wrong password
    const wrongRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'pending@example.com',
        password: 'WrongPassword999!',
      }),
    });

    // Security requirement: Status and error must be identical so attackers cannot guess passwords via pending accounts
    expect(correctRes.status).toBe(wrongRes.status);
    const correctBody = await correctRes.json();
    const wrongBody = await wrongRes.json();
    expect(correctBody.code).toBe(wrongBody.code);
  });

  test('4. verifyEmail does NOT create a dummy company with business_type="company" before business type selection', async () => {
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

    // Architectural requirement: businessType MUST NOT be defaulted to 'company'
    // It must clearly indicate onboarding is incomplete (e.g., null businessType)
    expect(body.user.businessType).toBeNull();
    if (body.company) {
      expect(body.company.businessType).toBeNull();
    }
  });

  test('5. Business setup persists selected Grocery/Superette type and rejects invalid types like "construction"', async () => {
    // Set up a verified owner with pending business type
    const compRes = await testPool.query(
      `INSERT INTO companies (name, business_type, currency) VALUES ('Pending Setup', 'company', 'DZD') RETURNING id`,
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

    // B. Successfully persists 'grocery'
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
    expect(validBody.data.business_type).toBe('grocery');

    // C. Verify persisted in PostgreSQL
    const checkDb = await testPool.query('SELECT business_type, name FROM companies WHERE id = $1', [companyId]);
    expect(checkDb.rows[0].business_type).toBe('grocery');
    expect(checkDb.rows[0].name).toBe('El-Amel Superette');
  });
});

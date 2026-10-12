const bcrypt = require('bcryptjs');
const { Client } = require('pg');
const { query } = require('../config/db');
const { provisionAdmin, normalizeEmail } = require('../scripts/create_admin');

describe('Admin Provisioning and Migration Safety Regression Suite', () => {
  let testClientId;
  const originalEnv = process.env.DATABASE_URL;

  beforeAll(async () => {
    // Clean up any test users that might remain from previous runs
    await query(
      `DELETE FROM users WHERE email LIKE '%@provision-test.modiri.ai'`,
    );
  });

  afterAll(async () => {
    await query(
      `DELETE FROM users WHERE email LIKE '%@provision-test.modiri.ai'`,
    );
  });

  describe('1. Input Validation and Normalization', () => {
    test('normalizes email consistently (lowercase and trim)', () => {
      expect(normalizeEmail('  ADMIN.Test@Provision-Test.Modiri.AI  ')).toBe(
        'admin.test@provision-test.modiri.ai',
      );
    });

    test('rejects missing or empty email/password', async () => {
      await expect(
        provisionAdmin({ email: '', password: 'SecretPassword123!' }),
      ).rejects.toThrow('Email and password are required');

      await expect(
        provisionAdmin({ email: 'test@provision-test.modiri.ai', password: '' }),
      ).rejects.toThrow('Email and password are required');
    });

    test('rejects invalid email formats', async () => {
      await expect(
        provisionAdmin({ email: 'notanemail', password: 'SecretPassword123!' }),
      ).rejects.toThrow('Invalid email format');
    });

    test('rejects short passwords (< 8 characters)', async () => {
      await expect(
        provisionAdmin({
          email: 'admin1@provision-test.modiri.ai',
          password: 'short',
        }),
      ).rejects.toThrow('Administrator password must be at least 8 characters');
    });

    test('rejects unapproved roles (only super_admin and support allowed)', async () => {
      await expect(
        provisionAdmin({
          email: 'admin1@provision-test.modiri.ai',
          password: 'ValidPassword123!',
          role: 'owner',
        }),
      ).rejects.toThrow("Role must be 'super_admin' or 'support'");
    });
  });

  describe('2. Fresh Administrator Provisioning', () => {
    test('successfully provisions a new super_admin', async () => {
      const email = 'fresh.superadmin@provision-test.modiri.ai';
      const password = 'SuperSecretPassword123!';

      const result = await provisionAdmin({
        email,
        password,
        name: 'Fresh Super Admin',
        role: 'super_admin',
      });

      expect(result.action).toBe('created');
      expect(result.user.email).toBe(email);
      expect(result.user.role).toBe('super_admin');

      // Verify in DB
      const dbRes = await query(
        `SELECT id, email, role, password_hash FROM users WHERE email = $1`,
        [email],
      );
      expect(dbRes.rows.length).toBe(1);
      const user = dbRes.rows[0];
      expect(user.role).toBe('super_admin');

      // Verify bcrypt 12 rounds
      const matches = await bcrypt.compare(password, user.password_hash);
      expect(matches).toBe(true);
      expect(user.password_hash.startsWith('$2a$12$') || user.password_hash.startsWith('$2b$12$')).toBe(true);
    });
  });

  describe('3. Re-running Provisioning & Overwrite Protection', () => {
    test('re-running provisioning for an existing admin without allowUpdate REFUSES overwrite', async () => {
      const email = 'existing.admin@provision-test.modiri.ai';
      const originalPassword = 'OriginalPassword123!';
      const newPassword = 'NewAttemptedPassword456!';

      // Provision initial admin
      const initial = await provisionAdmin({
        email,
        password: originalPassword,
        name: 'Original Admin',
        role: 'super_admin',
      });
      expect(initial.action).toBe('created');

      // Get initial hash
      const initialDb = await query(
        `SELECT password_hash, role FROM users WHERE email = $1`,
        [email],
      );
      const originalHash = initialDb.rows[0].password_hash;

      // Attempt re-provision without allowUpdate
      await expect(
        provisionAdmin({
          email,
          password: newPassword,
          name: 'Changed Admin',
          role: 'support',
          allowUpdate: false,
        }),
      ).rejects.toThrow('Administrator account "existing.admin@provision-test.modiri.ai" already exists');

      // Verify DB hash and role did NOT change
      const afterDb = await query(
        `SELECT password_hash, role FROM users WHERE email = $1`,
        [email],
      );
      expect(afterDb.rows[0].password_hash).toBe(originalHash);
      expect(afterDb.rows[0].role).toBe('super_admin');

      // Old password still works
      const oldMatches = await bcrypt.compare(originalPassword, afterDb.rows[0].password_hash);
      expect(oldMatches).toBe(true);
    });

    test('re-running provisioning with explicit allowUpdate: true updates credentials deliberately', async () => {
      const email = 'existing.admin@provision-test.modiri.ai';
      const updatedPassword = 'DeliberateUpdatePassword789!';

      const updateResult = await provisionAdmin({
        email,
        password: updatedPassword,
        name: 'Updated Name Admin',
        role: 'support',
        allowUpdate: true,
      });

      expect(updateResult.action).toBe('updated');
      expect(updateResult.user.role).toBe('support');

      const afterDb = await query(
        `SELECT role, password_hash FROM users WHERE email = $1`,
        [email],
      );
      expect(afterDb.rows[0].role).toBe('support');
      const newMatches = await bcrypt.compare(updatedPassword, afterDb.rows[0].password_hash);
      expect(newMatches).toBe(true);
    });
  });

  describe('4. Ordinary User Privilege Escalation Defense', () => {
    test('refuses to elevate an existing regular business user (owner/employee)', async () => {
      const regularEmail = 'business.owner@provision-test.modiri.ai';
      const regularPassword = 'OwnerPassword123!';

      // Create regular business user
      const compRes = await query(
        `INSERT INTO companies (name, business_type, currency)
         VALUES ('Test Regular Co', 'company', 'DZD')
         RETURNING id`,
      );
      const compId = compRes.rows[0].id;

      const pwHash = await bcrypt.hash(regularPassword, 10);
      await query(
        `INSERT INTO users (company_id, name, email, password_hash, role, email_verified)
         VALUES ($1, 'Regular Owner', $2, $3, 'owner', true)`,
        [compId, regularEmail, pwHash],
      );

      // Attempt to provision admin with same email
      await expect(
        provisionAdmin({
          email: regularEmail,
          password: 'AttackerPassword999!',
          role: 'super_admin',
          allowUpdate: true, // Even if allowUpdate is true, regular accounts must NOT be elevated
        }),
      ).rejects.toThrow('SECURITY ALERT: Account "business.owner@provision-test.modiri.ai" already exists as a regular business user with role "owner"');

      // Verify owner account is completely unchanged
      const ownerDb = await query(
        `SELECT role, password_hash, company_id FROM users WHERE email = $1`,
        [regularEmail],
      );
      expect(ownerDb.rows[0].role).toBe('owner');
      expect(ownerDb.rows[0].company_id).toBe(compId);
      const matches = await bcrypt.compare(regularPassword, ownerDb.rows[0].password_hash);
      expect(matches).toBe(true);
    });
  });

  describe('5. Migration Failure Safety & Transaction Atomic Rollback', () => {
    test('migration 034 SQL executes cleanly within an explicit BEGIN/COMMIT block', async () => {
      const fs = require('fs');
      const path = require('path');
      const sqlPath = path.join(
        __dirname,
        '../../migrations/034_create_subscriptions_licensing_payments.sql',
      );
      const sql = fs.readFileSync(sqlPath, 'utf8');

      const client = new Client({ connectionString: process.env.DATABASE_URL });
      await client.connect();
      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('COMMIT');
      } finally {
        await client.end();
      }
    });

    test('partial failure in a transaction rolls back completely without committing partial tables', async () => {
      const client = new Client({ connectionString: process.env.DATABASE_URL });
      await client.connect();

      const canaryTable = 'canary_test_rollback_table';
      try {
        await client.query('BEGIN');
        await client.query(`CREATE TABLE ${canaryTable} (id SERIAL PRIMARY KEY, note TEXT)`);
        // Intentionally invalid statement to trigger failure
        await client.query(`INSERT INTO non_existent_table_for_rollback_test VALUES (1)`);
        await client.query('COMMIT');
      } catch (err) {
        await client.query('ROLLBACK');
      } finally {
        // Verify canary table does NOT exist
        const check = await client.query(
          `SELECT 1 FROM information_schema.tables WHERE table_name = $1`,
          [canaryTable],
        );
        expect(check.rows.length).toBe(0);
        await client.end();
      }
    });

    test('migration advisory lock serializes execution', async () => {
      const client1 = new Client({ connectionString: process.env.DATABASE_URL });
      const client2 = new Client({ connectionString: process.env.DATABASE_URL });
      await client1.connect();
      await client2.connect();

      try {
        // Client 1 acquires lock
        const lockRes1 = await client1.query(
          "SELECT pg_try_advisory_lock(hashtext('smartbiz_schema_migrations_lock')) AS locked",
        );
        expect(lockRes1.rows[0].locked).toBe(true);

        // Client 2 attempts to acquire same lock and is rejected
        const lockRes2 = await client2.query(
          "SELECT pg_try_advisory_lock(hashtext('smartbiz_schema_migrations_lock')) AS locked",
        );
        expect(lockRes2.rows[0].locked).toBe(false);

        // Client 1 releases lock
        await client1.query(
          "SELECT pg_advisory_unlock(hashtext('smartbiz_schema_migrations_lock'))",
        );

        // Client 2 can now acquire lock
        const lockRes3 = await client2.query(
          "SELECT pg_try_advisory_lock(hashtext('smartbiz_schema_migrations_lock')) AS locked",
        );
        expect(lockRes3.rows[0].locked).toBe(true);
        await client2.query(
          "SELECT pg_advisory_unlock(hashtext('smartbiz_schema_migrations_lock'))",
        );
      } finally {
        await client1.end();
        await client2.end();
      }
    });
  });

  describe('6. Concurrency and Chargily Secret Strictness', () => {
    test('concurrent provisioning attempts on same non-existent email fail safely via unique index', async () => {
      const email = 'race.admin@provision-test.modiri.ai';
      const password = 'RacePassword123!';

      // Run two provisioning attempts concurrently
      const results = await Promise.allSettled([
        provisionAdmin({ email, password, name: 'Race Admin 1' }),
        provisionAdmin({ email, password, name: 'Race Admin 2' }),
      ]);

      const fulfilled = results.filter((r) => r.status === 'fulfilled');
      const rejected = results.filter((r) => r.status === 'rejected');

      // Exactly one must succeed and one must be rejected safely
      expect(fulfilled.length).toBe(1);
      expect(rejected.length).toBe(1);
      expect(rejected[0].reason.message).toMatch(
        /Administrator account .* already exists|was created concurrently/,
      );

      // Verify only 1 user exists in DB
      const dbRes = await query('SELECT id FROM users WHERE email = $1', [email]);
      expect(dbRes.rows.length).toBe(1);
    });

    test('processChargilyWebhook strictly requires secretKey and refuses to substitute apiKey', async () => {
      const paymentsService = require('../modules/payments/payments.service');
      const subscriptionConfig = require('../config/subscription');

      // Mock configuration with ONLY apiKey present (no secretKey)
      const originalSecret = subscriptionConfig.chargily.secretKey;
      const originalApi = subscriptionConfig.chargily.apiKey;

      try {
        subscriptionConfig.chargily.secretKey = null;
        subscriptionConfig.chargily.apiKey = 'test_pk_some_public_api_key';

        await expect(
          paymentsService.processChargilyWebhook({
            rawBody: Buffer.from('{"test": true}'),
            signatureHeader: 'somehexsignature',
            eventData: { id: 'evt_test' },
          }),
        ).rejects.toThrow('Payment webhook secret is unconfigured');
      } finally {
        subscriptionConfig.chargily.secretKey = originalSecret;
        subscriptionConfig.chargily.apiKey = originalApi;
      }
    });
  });
});


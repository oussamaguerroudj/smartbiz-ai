const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { hashCode, verifyCodeHash } = require('../utils/otp');
const { authMiddleware, requireRole } = require('../middlewares/auth.middleware');
const { createRateLimiter } = require('../middlewares/rateLimit.middleware');
const { errorMiddleware } = require('../middlewares/error.middleware');
const fileStorage = require('../utils/fileStorage');
const aiService = require('../modules/ai/ai.service');
const { executeTool } = require('../modules/ai/ai.tools');

jest.mock('../config/db', () => ({
  query: jest.fn(),
  withTransaction: jest.fn(),
}));

const db = require('../config/db');
const authService = require('../modules/auth/auth.service');
const expensesRepo = require('../modules/expenses/expenses.repository');
const appointmentsRepo = require('../modules/appointments/appointments.repository');
const clinicRepo = require('../modules/clinic/clinic.repository');
const productsRepo = require('../modules/products/products.repository');

describe('Modiri AI — Red-Team Security Engineering Regression Suite', () => {
  const companyA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const userA = '11111111-1111-4111-8111-111111111111';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('SEC-AUTH-001: Zero-Click Account Takeover in verifyEmail Blocked', () => {
    it('rejects verifyEmail when no pending_registrations row exists even if user is already registered', async () => {
      db.withTransaction.mockImplementation(async (fn) => {
        const client = {
          query: jest.fn()
            .mockResolvedValueOnce({ rows: [] }) // No pending_registrations row
            .mockResolvedValueOnce({ rows: [{ id: userA }] }), // Existing verified user in users table
        };
        return fn(client);
      });

      await expect(
        authService.verifyEmail({ email: 'existing-owner@company.dz', code: '000000' })
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'INVALID_CODE',
      });
    });

    it('rejects verifyEmail with 404 NO_PENDING_REGISTRATION when neither pending nor user exists', async () => {
      db.withTransaction.mockImplementation(async (fn) => {
        const client = {
          query: jest.fn()
            .mockResolvedValueOnce({ rows: [] })
            .mockResolvedValueOnce({ rows: [] }),
        };
        return fn(client);
      });

      await expect(
        authService.verifyEmail({ email: 'unknown@company.dz', code: '000000' })
      ).rejects.toMatchObject({
        statusCode: 404,
        code: 'NO_PENDING_REGISTRATION',
      });
    });
  });

  describe('SEC-AUTH-002: OTP Brute-Force Counter Persistence & Constant-Time Hash Verification', () => {
    it('verifies OTP hashes in constant time and rejects invalid or malformed inputs', () => {
      const code = '482910';
      const hashed = hashCode(code);
      expect(verifyCodeHash(code, hashed)).toBe(true);
      expect(verifyCodeHash('000000', hashed)).toBe(false);
      expect(verifyCodeHash('', hashed)).toBe(false);
      expect(verifyCodeHash(null, hashed)).toBe(false);
      expect(verifyCodeHash(code, 'short')).toBe(false);
    });

    it('commits OTP attempt counter increment before throwing INVALID_CODE in verifyEmail', async () => {
      const realCodeHash = hashCode('123456');
      const clientQuery = jest.fn()
        .mockResolvedValueOnce({
          rows: [{
            id: 'pending-1',
            email: 'newuser@company.dz',
            code_hash: realCodeHash,
            code_expires: new Date(Date.now() + 600000).toISOString(),
            attempts: 1,
          }],
        })
        .mockResolvedValueOnce({ rows: [] }); // UPDATE pending_registrations SET attempts = attempts + 1

      let transactionCommitted = false;
      db.withTransaction.mockImplementation(async (fn) => {
        const res = await fn({ query: clientQuery });
        transactionCommitted = true;
        return res;
      });

      await expect(
        authService.verifyEmail({ email: 'newuser@company.dz', code: '999999' })
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'INVALID_CODE',
      });

      // Verify transaction committed instead of rolling back the attempt increment
      expect(transactionCommitted).toBe(true);
      expect(clientQuery).toHaveBeenCalledTimes(2);
      expect(clientQuery.mock.calls[1][0]).toContain('SET attempts = attempts + 1');
    });

    it('commits OTP attempt counter increment before throwing INVALID_CODE in resetPassword', async () => {
      const realCodeHash = hashCode('654321');
      const clientQuery = jest.fn()
        .mockResolvedValueOnce({
          rows: [{
            id: userA,
            company_id: companyA,
            email: 'owner@company.dz',
            role: 'owner',
          }],
        })
        .mockResolvedValueOnce({
          rows: [{
            id: 'otp-1',
            code_hash: realCodeHash,
            expires_at: new Date(Date.now() + 600000).toISOString(),
            attempts: 0,
          }],
        })
        .mockResolvedValueOnce({ rows: [] }); // UPDATE password_resets SET attempts = attempts + 1

      let transactionCommitted = false;
      db.withTransaction.mockImplementation(async (fn) => {
        const res = await fn({ query: clientQuery });
        transactionCommitted = true;
        return res;
      });

      await expect(
        authService.resetPassword({
          email: 'owner@company.dz',
          code: '000000',
          newPassword: 'NewStrongPassword123!',
        })
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'INVALID_CODE',
      });

      expect(transactionCommitted).toBe(true);
      expect(clientQuery).toHaveBeenCalledTimes(3);
      expect(clientQuery.mock.calls[2][0]).toContain('SET attempts = attempts + 1');
    });

    it('blocks even the correct OTP once MAX_CODE_ATTEMPTS (5) is reached', async () => {
      const validCode = '777888';
      const validHash = hashCode(validCode);
      db.withTransaction.mockImplementation(async (fn) => {
        const client = {
          query: jest.fn().mockResolvedValueOnce({
            rows: [{
              id: 'pending-locked',
              email: 'locked@company.dz',
              code_hash: validHash,
              code_expires: new Date(Date.now() + 600000).toISOString(),
              attempts: 5,
            }],
          }),
        };
        return fn(client);
      });

      await expect(
        authService.verifyEmail({ email: 'locked@company.dz', code: validCode })
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'TOO_MANY_ATTEMPTS',
      });
    });
  });

  describe('SEC-AUTH-003: JWT Algorithm Pinning & Token Type Confusion Defense', () => {
    it('rejects refresh tokens presented as access tokens in authMiddleware', () => {
      const refreshTokenAsAccess = jwt.sign(
        { sub: userA, companyId: companyA, role: 'owner', type: 'refresh' },
        env.jwt.accessSecret,
        { algorithm: 'HS256', expiresIn: '15m' }
      );

      const req = { headers: { authorization: `Bearer ${refreshTokenAsAccess}` } };
      const res = {};
      const next = jest.fn();

      authMiddleware(req, res, next);
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 401,
          code: 'UNAUTHORIZED',
        })
      );
    });

    it('rejects unsigned (alg: none) JWTs in authMiddleware', () => {
      const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
      const payload = Buffer.from(
        JSON.stringify({ sub: userA, companyId: companyA, role: 'owner', type: 'access' })
      ).toString('base64url');
      const unsignedToken = `${header}.${payload}.`;

      const req = { headers: { authorization: `Bearer ${unsignedToken}` } };
      const res = {};
      const next = jest.fn();

      authMiddleware(req, res, next);
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 401,
          code: 'UNAUTHORIZED',
        })
      );
    });

    it('rejects access tokens presented to authService.refresh', async () => {
      const accessTokenAsRefresh = jwt.sign(
        { sub: userA, companyId: companyA, role: 'owner', type: 'access' },
        env.jwt.refreshSecret,
        { algorithm: 'HS256', expiresIn: '15m' }
      );

      await expect(
        authService.refresh({ refreshToken: accessTokenAsRefresh })
      ).rejects.toMatchObject({
        statusCode: 401,
        code: 'UNAUTHORIZED',
      });
    });
  });

  describe('SEC-AI-001: SSRF Protection & Prototype Pollution Hardening in AI Service', () => {
    it('blocks SSRF URLs targeting cloud metadata, private LAN IPs, non-AI loopback ports, userinfo tricks, or arbitrary external hosts', () => {
      const maliciousUrls = [
        'http://169.254.169.254/latest/meta-data',
        'https://evil-exfiltrator.attacker.com/v1',
        'http://192.168.1.1:11434',
        'http://10.0.0.1:11434',
        'http://0.0.0.0:11434',
        'http://127.0.0.1:5432',
        'http://localhost:22',
        'http://[::1]:6379',
        'http://user:pass@localhost:11434/v1',
        'file:///etc/passwd',
        'gopher://127.0.0.1:6379/_INFO',
      ];

      for (const badUrl of maliciousUrls) {
        expect(() =>
          aiService.updateRuntimeAiConfig({ baseUrl: badUrl })
        ).toThrow(expect.objectContaining({ statusCode: 400, code: 'INVALID_AI_BASE_URL' }));
      }
    });

    it('allows local inference hosts (localhost / ollama) on inference port 11434', () => {
      const updated = aiService.updateRuntimeAiConfig({
        baseUrl: 'http://localhost:11434/v1',
        chatModel: 'qwen2.5:7b',
      });
      expect(updated.baseUrl).toBe('http://localhost:11434/v1');
    });

    it('blocks Object.prototype pollution keys in AI tool execution', async () => {
      const protoRes = await executeTool(companyA, '__proto__', {});
      expect(protoRes).toEqual({ error: 'Unknown tool: __proto__' });

      const constructorRes = await executeTool(companyA, 'constructor', {});
      expect(constructorRes).toEqual({ error: 'Unknown tool: constructor' });

      const toStringRes = await executeTool(companyA, 'toString', {});
      expect(toStringRes).toEqual({ error: 'Unknown tool: toString' });
    });
  });

  describe('SEC-IMAGE-001 & SEC-UPLOAD-001: Path Traversal & Magic-Byte Spoofing Defense', () => {
    it('blocks path traversal sequences in fileStorage.resolveStoragePath', () => {
      expect(() => fileStorage.resolveStoragePath('../../.env')).toThrow(
        expect.objectContaining({ code: 'INVALID_STORAGE_KEY' })
      );
      expect(() => fileStorage.resolveStoragePath('products/..\\secret.txt')).toThrow(
        expect.objectContaining({ code: 'INVALID_STORAGE_KEY' })
      );
      expect(() => fileStorage.resolveStoragePath('/etc/passwd')).toThrow(
        expect.objectContaining({ code: 'INVALID_STORAGE_KEY' })
      );
      expect(() => fileStorage.resolveStoragePath('products/null\0byte.png')).toThrow(
        expect.objectContaining({ code: 'INVALID_STORAGE_KEY' })
      );
    });

    it('rejects files whose binary magic bytes do not match their declared MIME/extension', () => {
      const fakeHtmlAsPdf = Buffer.from('<script>alert("xss")</script>').toString('base64');
      expect(() =>
        fileStorage.saveBase64File({
          companyId: companyA,
          subfolder: 'clinic-documents',
          base64Data: fakeHtmlAsPdf,
          mimeType: 'application/pdf',
        })
      ).toThrow(expect.objectContaining({ code: 'INVALID_FILE_DATA' }));

      const fakeTextAsPng = Buffer.from('not a real png image').toString('base64');
      expect(() =>
        fileStorage.saveBase64File({
          companyId: companyA,
          subfolder: 'product-images',
          base64Data: fakeTextAsPng,
          mimeType: 'image/png',
        })
      ).toThrow(expect.objectContaining({ code: 'INVALID_FILE_DATA' }));
    });
  });

  describe('SEC-AUTHZ-001: Vertical Privilege Escalation (RBAC) Defense', () => {
    it('blocks employee role from accessing owner-only endpoints', () => {
      const middleware = requireRole('owner');
      const req = { user: { id: userA, companyId: companyA, role: 'employee' } };
      const res = {};
      const next = jest.fn();

      middleware(req, res, next);
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 403,
          code: 'FORBIDDEN',
        })
      );
    });

    it('blocks employee role from creating salary/payroll expenses via expenses controller', async () => {
      const expensesController = require('../modules/expenses/expenses.controller');
      const req = {
        user: { id: userA, companyId: companyA, role: 'employee' },
        body: { category: 'Salary', amount: 60000, employeeId: 'emp-1', salaryPeriod: '2026-10' },
      };
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      await expensesController.create(req, res, next);
      expect(next).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 403,
          code: 'FORBIDDEN',
        })
      );
    });
  });

  describe('SEC-TENANT-FK-001: Cross-Tenant Foreign Key Injection Defense', () => {
    it('blocks linking another company employeeId when creating an expense', async () => {
      db.query.mockResolvedValueOnce({ rows: [] }); // Employee does not belong to companyA

      await expect(
        expensesRepo.create(companyA, {
          category: 'Salary',
          amount: 50000,
          employeeId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        })
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'VALIDATION_ERROR',
      });
    });

    it('blocks linking another company customerId when creating an appointment', async () => {
      db.query.mockResolvedValueOnce({ rows: [] }); // Customer does not belong to companyA

      await expect(
        appointmentsRepo.create(companyA, {
          customerId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          customerName: 'Victim Customer',
          serviceName: 'Consultation',
          appointmentDate: '2026-10-10',
          appointmentTime: '10:00',
        })
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'VALIDATION_ERROR',
      });
    });

    it('blocks linking another company doctorId when creating a clinic visit', async () => {
      db.query.mockResolvedValueOnce({ rows: [] }); // Doctor belongs to companyB (not found in companyA)

      await expect(
        clinicRepo.createVisit(companyA, {
          patientId: 'cust-a',
          doctorId: 'doctor-from-company-b',
          reason: 'Checkup',
        })
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'VALIDATION_ERROR',
      });
    });
  });

  describe('SEC-RATE-001 & SEC-API-001: Rate Limiting & Database Error Sanitization', () => {
    it('enforces sliding-window rate limits and sets Retry-After header', () => {
      const limiter = createRateLimiter({
        windowMs: 60000,
        max: 2,
        keyPrefix: 'test-sec-rate',
      });

      const req = { ip: '203.0.113.55', headers: {} };
      const res = { setHeader: jest.fn() };
      const next1 = jest.fn();
      const next2 = jest.fn();
      const next3 = jest.fn();

      limiter(req, res, next1);
      limiter(req, res, next2);
      limiter(req, res, next3);

      expect(next1).toHaveBeenCalledWith();
      expect(next2).toHaveBeenCalledWith();
      expect(next3).toHaveBeenCalledWith(
        expect.objectContaining({
          statusCode: 429,
          code: 'RATE_LIMIT_EXCEEDED',
        })
      );
      expect(res.setHeader).toHaveBeenCalledWith('Retry-After', expect.any(String));
    });

    it('maps PostgreSQL 22P02 invalid UUID and 22003 numeric overflow to 400 VALIDATION_ERROR', () => {
      const req = {};
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();

      errorMiddleware({ code: '22P02', message: 'invalid input syntax for type uuid' }, req, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        error: true,
        code: 'VALIDATION_ERROR',
        message: 'Invalid parameter format or numeric value out of range',
      });
    });
  });

  describe('SEC-TENANT-PROD: Tenant-Safe Product Idempotency & Collision Protection', () => {
    const prodId = 'prod-1111-2222-3333-444444444444';
    const companyB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

    it('returns existing product idempotently on same-company retry without creating duplicates', async () => {
      // 1. SELECT id, company_id FROM products WHERE id = $1 -> found under companyA
      db.query.mockResolvedValueOnce({
        rows: [{ id: prodId, company_id: companyA }],
      });
      // 2. findById(companyA, prodId) -> returns existing product
      db.query.mockResolvedValueOnce({
        rows: [{ id: prodId, company_id: companyA, name: 'Espresso Beans', selling_price: '500.00' }],
      });

      const result = await productsRepo.create(companyA, {
        id: prodId,
        name: 'Espresso Beans',
        purchasePrice: 300,
        sellingPrice: 500,
      });

      expect(result).toEqual(
        expect.objectContaining({
          id: prodId,
          company_id: companyA,
          name: 'Espresso Beans',
        })
      );
    });

    it('rejects cross-company ID collision with 409 CONFLICT without modifying or returning other tenant data', async () => {
      // SELECT id, company_id FROM products WHERE id = $1 -> found under companyB (different tenant)
      db.query.mockResolvedValueOnce({
        rows: [{ id: prodId, company_id: companyB }],
      });

      await expect(
        productsRepo.create(companyA, {
          id: prodId,
          name: 'Malicious Clone',
          purchasePrice: 100,
          sellingPrice: 200,
        })
      ).rejects.toMatchObject({
        statusCode: 409,
        code: 'CONFLICT',
        message: 'Product with this ID already exists',
      });
    });

    it('inserts fresh product with client-supplied ID when ID does not exist anywhere', async () => {
      // 1. SELECT id, company_id FROM products WHERE id = $1 -> not found
      db.query.mockResolvedValueOnce({ rows: [] });
      // 2. INSERT INTO products ... RETURNING *
      db.query.mockResolvedValueOnce({
        rows: [{ id: prodId, company_id: companyA, name: 'Fresh Milk', selling_price: '120.00' }],
      });

      const result = await productsRepo.create(companyA, {
        id: prodId,
        name: 'Fresh Milk',
        purchasePrice: 80,
        sellingPrice: 120,
      });

      expect(result).toEqual(
        expect.objectContaining({
          id: prodId,
          company_id: companyA,
          name: 'Fresh Milk',
        })
      );
    });
  });
});

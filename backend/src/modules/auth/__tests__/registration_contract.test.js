const { validateRegister, VALID_INDUSTRIES, VALID_TYPES } = require('../auth.validators');
const authService = require('../auth.service');
const { query } = require('../../../config/db');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
  withTransaction: jest.fn((cb) => cb({ query: jest.fn() })),
}));

jest.mock('../../../utils/email', () => ({
  sendMail: jest.fn().mockResolvedValue(true),
}));

describe('Auth Registration Contract & Validation Tests', () => {
  let req, res, next;

  beforeEach(() => {
    jest.clearAllMocks();
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    next = jest.fn();
  });

  describe('validateRegister middleware', () => {
    // 1. successful registration
    test('1. successful registration: accepts valid registration payload', () => {
      req = {
        body: {
          name: 'Ahmed Store',
          email: 'ahmed@store.com',
          password: 'Password123!',
          industry: 'retail',
          type: 'retail_store',
        },
      };

      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // No error passed
    });

    // 2. missing industry
    test('2. missing industry: rejects when industry is omitted, null, or empty', () => {
      // Omitted
      req = {
        body: {
          name: 'Ahmed Store',
          email: 'ahmed@store.com',
          password: 'Password123!',
          type: 'retail_store',
        },
      };
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err1 = next.mock.calls[0][0];
      expect(err1.statusCode).toBe(400);
      expect(err1.message).toBe('industry is required');

      // Empty string
      next.mockClear();
      req.body.industry = '   ';
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err2 = next.mock.calls[0][0];
      expect(err2.statusCode).toBe(400);
      expect(err2.message).toBe('industry is required');

      // Null
      next.mockClear();
      req.body.industry = null;
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err3 = next.mock.calls[0][0];
      expect(err3.statusCode).toBe(400);
      expect(err3.message).toBe('industry is required');
    });

    // 3. missing type
    test('3. missing type: rejects when type is omitted, null, or empty', () => {
      // Omitted
      req = {
        body: {
          name: 'Ahmed Store',
          email: 'ahmed@store.com',
          password: 'Password123!',
          industry: 'retail',
        },
      };
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err1 = next.mock.calls[0][0];
      expect(err1.statusCode).toBe(400);
      expect(err1.message).toBe('type is required');

      // Empty string
      next.mockClear();
      req.body.type = '  ';
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err2 = next.mock.calls[0][0];
      expect(err2.statusCode).toBe(400);
      expect(err2.message).toBe('type is required');

      // Null
      next.mockClear();
      req.body.type = null;
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err3 = next.mock.calls[0][0];
      expect(err3.statusCode).toBe(400);
      expect(err3.message).toBe('type is required');
    });

    // 4. invalid industry/type
    test('4. invalid industry/type: rejects unknown industry or unknown type', () => {
      // Invalid industry
      req = {
        body: {
          name: 'Ahmed Store',
          email: 'ahmed@store.com',
          password: 'Password123!',
          industry: 'aerospace_unknown',
          type: 'retail_store',
        },
      };
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err1 = next.mock.calls[0][0];
      expect(err1.statusCode).toBe(400);
      expect(err1.message).toContain('industry must be one of');

      // Invalid type
      next.mockClear();
      req.body.industry = 'retail';
      req.body.type = 'spaceship_station';
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err2 = next.mock.calls[0][0];
      expect(err2.statusCode).toBe(400);
      expect(err2.message).toContain('type must be one of');
    });

    // 5. Flutter request payload matching backend schema
    test('5. Flutter request payload matching backend schema: accepts exact Flutter JSON body', () => {
      const flutterPayload = {
        name: 'Fatima Zahra',
        email: 'fatima@pharmacy.dz',
        password: 'SecurePassword2026!',
        industry: 'healthcare',
        type: 'pharmacy',
      };

      req = { body: flutterPayload };
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // Clean pass
    });
  });

  describe('authService.register with industry & type', () => {
    test('stores industry and type in pending_registrations and sends email', async () => {
      query.mockResolvedValueOnce({ rows: [] }); // No existing user
      query.mockResolvedValueOnce({ rows: [] }); // insert pending_registrations

      const result = await authService.register({
        name: 'Karim Superette',
        email: 'karim@superette.dz',
        password: 'Password123!',
        industry: 'retail',
        type: 'supermarket',
      });

      expect(result).toEqual({
        email: 'karim@superette.dz',
        pendingVerification: true,
      });

      // Verify DB query inserted industry and type
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('industry, type'),
        expect.arrayContaining(['retail', 'supermarket']),
      );
    });
  });
});

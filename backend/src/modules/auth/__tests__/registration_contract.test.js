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

    // 2. step 1 initial signup without industry and type
    test('2. initial signup: accepts payload with only name, email, password (no industry or type)', () => {
      req = {
        body: {
          name: 'Ahmed Modiri',
          email: 'ahmed@modiri.ai',
          password: 'Password123!',
        },
      };
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // Clean pass
    });

    // 3. allows null or empty industry/type
    test('3. allows null or empty industry and type during step 1', () => {
      req = {
        body: {
          name: 'Ahmed Modiri',
          email: 'ahmed@modiri.ai',
          password: 'Password123!',
          industry: null,
          type: '',
        },
      };
      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // Clean pass
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

    test('stores null industry and type for step 1 signup when omitted', async () => {
      query.mockResolvedValueOnce({ rows: [] }); // No existing user
      query.mockResolvedValueOnce({ rows: [] }); // insert pending_registrations

      const result = await authService.register({
        name: 'New Business Owner',
        email: 'owner@example.com',
        password: 'Password123!',
      });

      expect(result).toEqual({
        email: 'owner@example.com',
        pendingVerification: true,
      });

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('industry, type'),
        expect.arrayContaining([null, null]),
      );
    });
  });

  describe('authService.login business_type contract', () => {
    test('login returns authoritative businessType on both user and company objects', async () => {
      const bcrypt = require('bcrypt');
      const hash = await bcrypt.hash('Password123!', 10);

      query.mockResolvedValueOnce({
        rows: [
          {
            id: 'usr_clinic_1',
            company_id: 'comp_clinic_1',
            name: 'Dr. Amine',
            email: 'amine@clinic.dz',
            password_hash: hash,
            role: 'owner',
            email_verified: true,
            business_type: 'clinic',
            company_name: 'Dr Amine Clinic',
          },
        ],
      });

      const res = await authService.login({
        email: 'amine@clinic.dz',
        password: 'Password123!',
      });

      expect(res.user.businessType).toBe('clinic');
      expect(res.company.businessType).toBe('clinic');
      expect(res.company.name).toBe('Dr Amine Clinic');
      expect(res.accessToken).toBeDefined();
    });
  });
});

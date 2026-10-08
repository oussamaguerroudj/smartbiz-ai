const { validateRegister } = require('../auth.validators');
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

  describe('validateRegister middleware (Intended Contract)', () => {
    test('1. accepts valid registration payload (name, email, password)', () => {
      req = {
        body: {
          name: 'Ahmed Store',
          email: 'ahmed@store.com',
          password: 'Password123!',
        },
      };

      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(next).toHaveBeenCalledWith(); // No error passed
    });

    test('2. rejects name shorter than 2 characters', () => {
      req = {
        body: {
          name: 'A',
          email: 'ahmed@store.com',
          password: 'Password123!',
        },
      };

      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err = next.mock.calls[0][0];
      expect(err.statusCode).toBe(400);
      expect(err.message).toContain('name must be at least 2 characters');
    });

    test('3. rejects invalid email format', () => {
      req = {
        body: {
          name: 'Ahmed Store',
          email: 'not-an-email',
          password: 'Password123!',
        },
      };

      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err = next.mock.calls[0][0];
      expect(err.statusCode).toBe(400);
      expect(err.message).toContain('A valid email is required');
    });

    test('4. rejects password shorter than 6 characters', () => {
      req = {
        body: {
          name: 'Ahmed Store',
          email: 'ahmed@store.com',
          password: '12345',
        },
      };

      validateRegister(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err = next.mock.calls[0][0];
      expect(err.statusCode).toBe(400);
      expect(err.message).toContain('password must be at least 6 characters');
    });
  });

  describe('authService.register contract', () => {
    test('creates pending_registrations row without industry/type and returns pendingVerification', async () => {
      query.mockResolvedValueOnce({ rows: [] }); // No existing user
      query.mockResolvedValueOnce({ rows: [] }); // insert pending_registrations

      const result = await authService.register({
        name: 'New Founder',
        email: 'founder@example.com',
        password: 'Password123!',
      });

      expect(result).toEqual({
        email: 'founder@example.com',
        pendingVerification: true,
      });

      // Verify DB query inserted only canonical pending_registrations fields
      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO pending_registrations'),
        expect.arrayContaining(['New Founder', 'founder@example.com']),
      );
    });

    test('registration emits safe logs without leaking passwords or secrets', async () => {
      const consoleLogSpy = jest.spyOn(console, 'log').mockImplementation();
      query.mockResolvedValueOnce({ rows: [] });
      query.mockResolvedValueOnce({ rows: [{ id: 1 }] });

      await authService.register({
        name: 'Privacy User',
        email: 'secretuser@example.com',
        password: 'SuperSecretPassword123!',
      });

      const loggedMessages = consoleLogSpy.mock.calls.map((c) => c.join(' ')).join('\n');
      expect(loggedMessages).toContain('[AUTH-REGISTER] verification email dispatched successfully to recipient @example.com');
      expect(loggedMessages).not.toContain('SuperSecretPassword123!');
      consoleLogSpy.mockRestore();
    });
  });

  describe('authService.login business_type and onboarding contract', () => {
    test('login returns authoritative businessType and onboardingCompleted on both user and company', async () => {
      const bcrypt = require('bcryptjs');
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
            onboarding_completed: true,
          },
        ],
      });

      const res = await authService.login({
        email: 'amine@clinic.dz',
        password: 'Password123!',
      });

      expect(res.user.businessType).toBe('clinic');
      expect(res.user.onboardingCompleted).toBe(true);
      expect(res.company.businessType).toBe('clinic');
      expect(res.company.onboardingCompleted).toBe(true);
      expect(res.company.name).toBe('Dr Amine Clinic');
      expect(res.accessToken).toBeDefined();
    });
  });
});

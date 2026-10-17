const { validateGoogleSignIn, validateLinkGoogle } = require('../auth.validators');
const authService = require('../auth.service');
const { query, withTransaction } = require('../../../config/db');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
  withTransaction: jest.fn((cb) => {
    const client = {
      query: jest.fn(),
    };
    return cb(client);
  }),
}));

jest.mock('../../../utils/email', () => ({
  sendMail: jest.fn().mockResolvedValue(true),
}));

// Mock google-auth-library OAuth2Client
jest.mock('google-auth-library', () => {
  return {
    OAuth2Client: jest.fn().mockImplementation(() => ({
      verifyIdToken: jest.fn().mockImplementation(async ({ idToken }) => {
        if (idToken === 'invalid-token') {
          throw new Error('Invalid token signature');
        }
        if (idToken === 'unverified-email-token') {
          return {
            getPayload: () => ({
              sub: 'google-sub-unverified',
              email: 'unverified@example.com',
              email_verified: false,
              name: 'Unverified User',
              iss: 'accounts.google.com',
            }),
          };
        }
        return {
          getPayload: () => ({
            sub: 'google-sub-12345',
            email: 'googleuser@example.com',
            email_verified: true,
            name: 'Google User',
            picture: 'https://lh3.googleusercontent.com/photo.jpg',
            iss: 'https://accounts.google.com',
          }),
        };
      }),
    })),
  };
});

describe('Google Authentication Tests', () => {
  let req, res, next;

  beforeEach(() => {
    jest.clearAllMocks();
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    next = jest.fn();
  });

  describe('Validator: validateGoogleSignIn', () => {
    test('passes when idToken is a non-empty string', () => {
      req = { body: { idToken: 'valid-token' } };
      validateGoogleSignIn(req, res, next);
      expect(next).toHaveBeenCalledWith();
    });

    test('passes when code, codeVerifier, and redirectUri are non-empty strings', () => {
      req = {
        body: {
          code: 'test-auth-code',
          codeVerifier: 'test-verifier-123456',
          redirectUri: 'http://127.0.0.1:8080',
        },
      };
      validateGoogleSignIn(req, res, next);
      expect(next).toHaveBeenCalledWith();
    });

    test('rejects when idToken and code are missing or empty', () => {
      req = { body: {} };
      validateGoogleSignIn(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err = next.mock.calls[0][0];
      expect(err.statusCode).toBe(400);
      expect(err.code).toBe('VALIDATION_ERROR');
    });

    test('rejects when code is provided without codeVerifier or redirectUri', () => {
      req = { body: { code: 'test-code' } };
      validateGoogleSignIn(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      const err = next.mock.calls[0][0];
      expect(err.statusCode).toBe(400);
      expect(err.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('authService.googleSignIn', () => {
    test('rejects unverified Google email', async () => {
      await expect(
        authService.googleSignIn({ idToken: 'unverified-email-token' }),
      ).rejects.toMatchObject({
        statusCode: 403,
        code: 'GOOGLE_EMAIL_NOT_VERIFIED',
      });
    });

    test('logs in existing user found by google_id', async () => {
      query.mockImplementation(async (sql, params) => {
        if (sql.includes('FROM users') && sql.includes('google_id = $1')) {
          return {
            rows: [
              {
                id: 'u-1',
                company_id: 'c-1',
                name: 'Existing Google User',
                email: 'googleuser@example.com',
                role: 'owner',
                google_id: 'google-sub-12345',
                auth_provider: 'google',
                company_name: 'Existing Store',
                business_type: 'grocery',
                onboarding_completed: true,
                is_suspended: false,
              },
            ],
          };
        }
        return { rows: [] };
      });

      const result = await authService.googleSignIn({ idToken: 'valid-token' });
      expect(result).toHaveProperty('user');
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(result.user.email).toBe('googleuser@example.com');
      expect(result.user.authProvider).toBe('google');
      expect(result.user.isGoogleLinked).toBe(true);
    });

    test('rejects login if user account is suspended', async () => {
      query.mockImplementation(async (sql) => {
        if (sql.includes('FROM users') && sql.includes('google_id = $1')) {
          return {
            rows: [
              {
                id: 'u-suspended',
                company_id: 'c-1',
                email: 'googleuser@example.com',
                is_suspended: true,
              },
            ],
          };
        }
        return { rows: [] };
      });

      await expect(
        authService.googleSignIn({ idToken: 'valid-token' }),
      ).rejects.toMatchObject({
        statusCode: 403,
        code: 'ACCOUNT_SUSPENDED',
      });
    });

    test('NEVER automatically merges account when email matches existing password account', async () => {
      query.mockImplementation(async (sql) => {
        // Step 1: No user by google_id
        if (sql.includes('FROM users') && sql.includes('google_id = $1')) {
          return { rows: [] };
        }
        // Step 2: User found by email, but has a password set!
        if (sql.includes('FROM users') && sql.includes('lower(trim(email)) = $1')) {
          return {
            rows: [
              {
                id: 'u-existing-local',
                email: 'googleuser@example.com',
                password_hash: '$2b$10$somerealhash',
                auth_provider: 'local',
              },
            ],
          };
        }
        return { rows: [] };
      });

      await expect(
        authService.googleSignIn({ idToken: 'valid-token' }),
      ).rejects.toMatchObject({
        statusCode: 409,
        code: 'ACCOUNT_EXISTS_WITH_PASSWORD',
      });
    });

    test('creates new user and company atomically if user does not exist', async () => {
      query.mockImplementation(async (sql) => {
        // Step 1: No user by google_id
        if (sql.includes('FROM users') && sql.includes('google_id = $1')) {
          return { rows: [] };
        }
        // Step 2: No user by email
        if (sql.includes('FROM users') && sql.includes('lower(trim(email)) = $1')) {
          return { rows: [] };
        }
        return { rows: [] };
      });

      withTransaction.mockImplementation(async (cb) => {
        const client = {
          query: jest.fn().mockImplementation(async (sql, params) => {
            if (sql.includes('FOR UPDATE')) {
              return { rows: [] };
            }
            if (sql.includes('INSERT INTO companies')) {
              return {
                rows: [
                  {
                    id: 'new-comp-1',
                    name: "Google User's Business",
                    business_type: null,
                    onboarding_completed: false,
                  },
                ],
              };
            }
            if (sql.includes('INSERT INTO users')) {
              return {
                rows: [
                  {
                    id: 'new-u-1',
                    company_id: 'new-comp-1',
                    name: 'Google User',
                    email: 'googleuser@example.com',
                    role: 'owner',
                    email_verified: true,
                    google_id: 'google-sub-12345',
                    auth_provider: 'google',
                    avatar_url: 'https://lh3.googleusercontent.com/photo.jpg',
                  },
                ],
              };
            }
            return { rows: [] };
          }),
        };
        return cb(client);
      });

      const result = await authService.googleSignIn({ idToken: 'valid-token' });
      expect(result).toHaveProperty('user');
      expect(result.user.id).toBe('new-u-1');
      expect(result.user.authProvider).toBe('google');
      expect(result.user.isGoogleLinked).toBe(true);
      expect(result.company.id).toBe('new-comp-1');
      expect(result.company.businessType).toBeNull();
      expect(result.company.onboardingCompleted).toBe(false);
      expect(result.company.entitlementType).toBe('trial');
    });

    test('existing user with incomplete onboarding returns onboardingCompleted: false and preserves previously saved company name', async () => {
      query.mockImplementation(async (sql) => {
        if (sql.includes('FROM users u') && sql.includes('u.google_id = $1')) {
          return {
            rows: [
              {
                id: 'u-incomplete',
                company_id: 'c-incomplete',
                name: 'Incomplete User',
                email: 'incomplete@example.com',
                role: 'owner',
                google_id: 'google-sub-12345',
                auth_provider: 'google',
                company_name: 'Partially Setup Store',
                business_type: null,
                onboarding_completed: false,
                is_suspended: false,
              },
            ],
          };
        }
        return { rows: [] };
      });

      const result = await authService.googleSignIn({ idToken: 'valid-token' });
      expect(result.company.businessType).toBeNull();
      expect(result.company.onboardingCompleted).toBe(false);
      expect(result.company.name).toBe('Partially Setup Store');
    });

    test('existing user with completed onboarding returns onboardingCompleted: true and previously saved businessType', async () => {
      query.mockImplementation(async (sql) => {
        if (sql.includes('FROM users u') && sql.includes('u.google_id = $1')) {
          return {
            rows: [
              {
                id: 'u-complete',
                company_id: 'c-complete',
                name: 'Complete User',
                email: 'complete@example.com',
                role: 'owner',
                google_id: 'google-sub-12345',
                auth_provider: 'google',
                company_name: 'Done Supermarket',
                business_type: 'grocery',
                onboarding_completed: true,
                is_suspended: false,
              },
            ],
          };
        }
        return { rows: [] };
      });

      const result = await authService.googleSignIn({ idToken: 'valid-token' });
      expect(result.company.businessType).toBe('grocery');
      expect(result.company.onboardingCompleted).toBe(true);
      expect(result.company.name).toBe('Done Supermarket');
    });

    test('passes accepted audiences including Windows Desktop client ID to verifyIdToken', async () => {
      const { OAuth2Client } = require('google-auth-library');
      query.mockImplementation(async () => ({ rows: [] }));
      withTransaction.mockImplementation(async (cb) => {
        const client = {
          query: jest.fn().mockImplementation(async (sql) => {
            if (sql.includes('INSERT INTO companies')) {
              return { rows: [{ id: 'c-win', name: 'Win Store', business_type: null, onboarding_completed: false }] };
            }
            if (sql.includes('INSERT INTO users')) {
              return { rows: [{ id: 'u-win', email: 'googleuser@example.com', role: 'owner', email_verified: true, auth_provider: 'google' }] };
            }
            return { rows: [] };
          }),
        };
        return cb(client);
      });

      await authService.googleSignIn({ idToken: 'valid-token' });
      const mockOAuthInstance = OAuth2Client.mock.results[0]?.value;
      if (mockOAuthInstance) {
        expect(mockOAuthInstance.verifyIdToken).toHaveBeenCalledWith(
          expect.objectContaining({
            audience: expect.arrayContaining([
              '128675361201-9sql94sb7b2av7upaksoqunkvs1c4amp.apps.googleusercontent.com', // Web
              '128675361201-s1qac05sj36egh69a054ljmqukptt4tl.apps.googleusercontent.com', // Android
              '128675361201-qhb7u121simtqfq3nubaek2nhk0qae2f.apps.googleusercontent.com', // Windows Desktop
            ]),
          }),
        );
      }
    });

    test('throws GOOGLE_CLIENT_SECRET_NOT_CONFIGURED when secret is missing during code exchange', async () => {
      const env = require('../../../config/env');
      const savedSecret = env.google.windowsClientSecret;
      env.google.windowsClientSecret = '';

      try {
        await expect(
          authService.googleSignIn({
            code: 'test-code',
            codeVerifier: 'test-verifier',
            redirectUri: 'http://127.0.0.1:8080',
          }),
        ).rejects.toMatchObject({
          statusCode: 500,
          code: 'GOOGLE_CLIENT_SECRET_NOT_CONFIGURED',
        });
      } finally {
        env.google.windowsClientSecret = savedSecret;
      }
    });

    test('throws TOKEN_EXCHANGE_FAILED when Google token endpoint returns error response', async () => {
      const env = require('../../../config/env');
      const savedSecret = env.google.windowsClientSecret;
      env.google.windowsClientSecret = 'mock-windows-client-secret';

      const originalFetch = global.fetch;
      global.fetch = jest.fn().mockResolvedValue({
        ok: false,
        json: async () => ({
          error: 'invalid_grant',
          error_description: 'Code has expired',
        }),
      });

      try {
        await expect(
          authService.googleSignIn({
            code: 'expired-code',
            codeVerifier: 'test-verifier',
            redirectUri: 'http://127.0.0.1:8080',
          }),
        ).rejects.toMatchObject({
          statusCode: 400,
          code: 'TOKEN_EXCHANGE_FAILED',
        });
      } finally {
        env.google.windowsClientSecret = savedSecret;
        global.fetch = originalFetch;
      }
    });

    test('provides helpful guidance when Google rejects client secret (invalid_client)', async () => {
      const env = require('../../../config/env');
      const savedSecret = env.google.windowsClientSecret;
      env.google.windowsClientSecret = 'mismatched-web-secret-used-for-desktop';

      const originalFetch = global.fetch;
      global.fetch = jest.fn().mockResolvedValue({
        ok: false,
        json: async () => ({
          error: 'invalid_client',
          error_description: 'The provided client secret is invalid.',
        }),
      });

      try {
        await expect(
          authService.googleSignIn({
            code: 'test-code',
            codeVerifier: 'test-verifier',
            redirectUri: 'http://127.0.0.1:8080',
          }),
        ).rejects.toMatchObject({
          statusCode: 400,
          code: 'TOKEN_EXCHANGE_FAILED',
          message: expect.stringContaining('Ensure GOOGLE_WINDOWS_CLIENT_SECRET matches the Windows Desktop OAuth client'),
        });
      } finally {
        env.google.windowsClientSecret = savedSecret;
        global.fetch = originalFetch;
      }
    });

    test('successfully exchanges auth code for id_token and logs in user', async () => {
      const env = require('../../../config/env');
      const savedSecret = env.google.windowsClientSecret;
      env.google.windowsClientSecret = 'mock-windows-client-secret';

      const originalFetch = global.fetch;
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          id_token: 'valid-token',
          access_token: 'mock-google-access-token',
        }),
      });

      query.mockImplementation(async (sql, params) => {
        if (sql.includes('FROM users') && sql.includes('google_id = $1')) {
          return {
            rows: [
              {
                id: 'u-desktop',
                company_id: 'c-desktop',
                name: 'Google Desktop User',
                email: 'googleuser@example.com',
                role: 'owner',
                google_id: 'google-sub-12345',
                auth_provider: 'google',
                company_name: 'Desktop Company',
                business_type: 'retail',
                onboarding_completed: true,
                is_suspended: false,
              },
            ],
          };
        }
        return { rows: [] };
      });

      try {
        const result = await authService.googleSignIn({
          code: 'valid-auth-code',
          codeVerifier: 'valid-verifier-12345',
          redirectUri: 'http://127.0.0.1:54321',
          clientId: '128675361201-qhb7u121simtqfq3nubaek2nhk0qae2f.apps.googleusercontent.com',
        });

        expect(global.fetch).toHaveBeenCalledWith(
          'https://oauth2.googleapis.com/token',
          expect.objectContaining({
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: expect.stringContaining('code=valid-auth-code'),
          }),
        );
        expect(result).toHaveProperty('user');
        expect(result.user.email).toBe('googleuser@example.com');
        expect(result.company.businessType).toBe('retail');
      } finally {
        env.google.windowsClientSecret = savedSecret;
        global.fetch = originalFetch;
      }
    });
  });

  describe('authService.linkGoogleAccount', () => {
    test('fails if user is already linked to another Google account', async () => {
      query.mockImplementation(async (sql) => {
        if (sql.includes('FROM users u') && sql.includes('u.id = $1')) {
          return { rows: [{ id: 'u-local', password_hash: null }] };
        }
        if (sql.includes('FROM users') && sql.includes('google_id = $1')) {
          return { rows: [{ id: 'other-user' }] };
        }
        return { rows: [] };
      });

      await expect(
        authService.linkGoogleAccount('u-local', { idToken: 'valid-token' }),
      ).rejects.toMatchObject({
        statusCode: 409,
        code: 'GOOGLE_ACCOUNT_ALREADY_LINKED',
      });
    });
  });

  describe('authService.unlinkGoogleAccount', () => {
    test('fails if user has no password set', async () => {
      query.mockResolvedValueOnce({
        rows: [
          {
            id: 'u-1',
            google_id: 'google-sub-123',
            password_hash: null, // pure Google account
          },
        ],
      });

      await expect(
        authService.unlinkGoogleAccount('u-1', { password: 'somepassword' }),
      ).rejects.toMatchObject({
        statusCode: 400,
        code: 'PASSWORD_NOT_SET',
      });
    });
  });
});

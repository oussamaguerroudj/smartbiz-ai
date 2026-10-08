describe('Production Email Boot Validation', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  test('throws in production when BREVO_API_KEY is missing', () => {
    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGIN = '*';
    process.env.DATABASE_URL = 'postgresql://localhost:5432/db';
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.JWT_REFRESH_SECRET = 'b'.repeat(32);
    delete process.env.BREVO_API_KEY;

    expect(() => require('../env')).toThrow('BREVO_API_KEY is required in production');
  });

  test('succeeds in production when BREVO_API_KEY is provided', () => {
    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGIN = '*';
    process.env.DATABASE_URL = 'postgresql://localhost:5432/db';
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.JWT_REFRESH_SECRET = 'b'.repeat(32);
    process.env.BREVO_API_KEY = 'xkeysib-test-dummy-key';

    const env = require('../env');
    expect(env.brevo.apiKey).toBe('xkeysib-test-dummy-key');
    expect(env.brevo.fromEmail).toBe('oussama.guerroudj@ensia.edu.dz');
    expect(env.brevo.fromName).toBe('Modiri AI');
  });
});

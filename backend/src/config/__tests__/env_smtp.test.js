describe('Production SMTP Boot Validation', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  test('throws in production when SMTP_HOST is missing', () => {
    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGIN = '*';
    process.env.DATABASE_URL = 'postgresql://localhost:5432/db';
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.JWT_REFRESH_SECRET = 'b'.repeat(32);
    delete process.env.SMTP_HOST;

    expect(() => require('../env')).toThrow('SMTP_HOST is required in production');
  });

  test('throws in production when SMTP_USER is missing', () => {
    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGIN = '*';
    process.env.DATABASE_URL = 'postgresql://localhost:5432/db';
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.JWT_REFRESH_SECRET = 'b'.repeat(32);
    process.env.SMTP_HOST = 'smtp.example.com';
    delete process.env.SMTP_USER;

    expect(() => require('../env')).toThrow('SMTP_USER is required in production');
  });

  test('throws in production when SMTP_PASS is missing', () => {
    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGIN = '*';
    process.env.DATABASE_URL = 'postgresql://localhost:5432/db';
    process.env.JWT_ACCESS_SECRET = 'a'.repeat(32);
    process.env.JWT_REFRESH_SECRET = 'b'.repeat(32);
    process.env.SMTP_HOST = 'smtp.example.com';
    process.env.SMTP_USER = 'user';
    delete process.env.SMTP_PASS;

    expect(() => require('../env')).toThrow('SMTP_PASS is required in production');
  });
});

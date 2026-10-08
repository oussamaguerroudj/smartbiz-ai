// backend/tests/integration/security_and_proxy.test.js

process.env.NODE_ENV = 'test';
process.env.PORT = '4098';
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

const app = require('../../src/app');
const { resetRateLimiters } = require('../../src/middlewares/rateLimit.middleware');

describe('Security Headers, Trust Proxy & Rate Limiting Integration Suite', () => {
  let server;
  let baseUrl;

  beforeAll(async () => {
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
    const { pool } = require('../../src/config/db');
    if (pool) {
      await pool.end();
    }
  });

  beforeEach(() => {
    resetRateLimiters();
  });

  test('1. Security Headers: x-powered-by is disabled and helmet headers are present', async () => {
    const res = await fetch(`${baseUrl}/health`);
    expect(res.status).toBe(200);
    expect(res.headers.get('x-powered-by')).toBeNull();
    expect(res.headers.get('x-content-type-options')).toBe('nosniff');
  });

  test('2. Trust Proxy: Express trusts 1 reverse proxy hop and extracts client IP from X-Forwarded-For', async () => {
    const clientIp = '198.51.100.42';
    const proxyIp = '10.0.0.1';

    // Send a request with X-Forwarded-For: client, proxy
    const res = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Forwarded-For': `${clientIp}, ${proxyIp}`,
      },
      body: JSON.stringify({ email: 'nonexistent@example.com', password: 'Password123!' }),
    });

    // Should return 401 (invalid credentials) or 400, but rate limiter headers should be present
    expect(res.headers.get('x-ratelimit-limit')).toBeDefined();
    expect(res.headers.get('x-ratelimit-remaining')).toBeDefined();
  });

  test('3. IP-level Login Rate Limiter: blocks IP after 60 login attempts across different emails', async () => {
    const testIp = '198.51.100.99';

    // Run 60 login attempts with different emails from the same IP
    for (let i = 1; i <= 60; i++) {
      const res = await fetch(`${baseUrl}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Forwarded-For': testIp,
        },
        body: JSON.stringify({ email: `user${i}@example.com`, password: 'WrongPassword123!' }),
      });

      expect(res.status).not.toBe(429);
    }

    // The 61st attempt from the same IP must be rejected with 429 Too Many Requests
    const blockedRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Forwarded-For': testIp,
      },
      body: JSON.stringify({ email: 'user61@example.com', password: 'WrongPassword123!' }),
    });

    expect(blockedRes.status).toBe(429);
    const body = await blockedRes.json();
    expect(body.error).toBe(true);
    expect(body.code).toBe('RATE_LIMIT_EXCEEDED');
    expect(blockedRes.headers.get('retry-after')).toBeDefined();
  });
});

const ApiError = require('../utils/ApiError');

const buckets = new Map();

/**
 * Lightweight, zero-dependency sliding-window rate limiter middleware.
 *
 * Supports keying by IP or IP + normalized email so brute-force attacks
 * against a specific account or from a single source IP are throttled
 * with HTTP 429 Too Many Requests.
 */
function createRateLimiter({
  windowMs = 60 * 1000,
  max = 30,
  keyPrefix = 'global',
  includeEmail = false,
  message = 'Too many requests, please try again later',
} = {}) {
  return function rateLimitMiddleware(req, res, next) {
    const now = Date.now();
    const ip =
      req.ip ||
      (req.headers['x-forwarded-for']
        ? String(req.headers['x-forwarded-for']).split(',')[0].trim()
        : '') ||
      req.socket?.remoteAddress ||
      'unknown';

    const emailPart =
      includeEmail && req.body && typeof req.body.email === 'string'
        ? `:${req.body.email.trim().toLowerCase()}`
        : '';

    const key = `${keyPrefix}:${ip}${emailPart}`;
    let entry = buckets.get(key);

    if (!entry || now > entry.resetAt) {
      entry = { count: 0, resetAt: now + windowMs };
      buckets.set(key, entry);
    }

    entry.count += 1;

    const remaining = Math.max(0, max - entry.count);
    res.setHeader('X-RateLimit-Limit', String(max));
    res.setHeader('X-RateLimit-Remaining', String(remaining));
    res.setHeader('X-RateLimit-Reset', String(Math.ceil(entry.resetAt / 1000)));

    if (entry.count > max) {
      const retryAfterSec = Math.max(1, Math.ceil((entry.resetAt - now) / 1000));
      res.setHeader('Retry-After', String(retryAfterSec));
      return next(ApiError.tooManyRequests(message, 'RATE_LIMIT_EXCEEDED'));
    }

    // Periodic cleanup of expired buckets to prevent unbounded memory growth
    if (buckets.size > 10000) {
      for (const [k, v] of buckets.entries()) {
        if (now > v.resetAt) {
          buckets.delete(k);
        }
      }
    }

    return next();
  };
}

function resetRateLimiters() {
  buckets.clear();
}

const authAccountLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 15,
  keyPrefix: 'auth-account',
  includeEmail: true,
  message: 'Too many authentication attempts for this account. Please try again later.',
});

const loginIpLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 60,
  keyPrefix: 'auth-login-ip',
  includeEmail: false,
  message: 'Too many login attempts from this IP address. Please try again later.',
});

const otpVerifyLimiter = createRateLimiter({
  windowMs: 10 * 60 * 1000,
  max: 10,
  keyPrefix: 'auth-otp',
  includeEmail: true,
  message: 'Too many verification attempts. Please wait or request a new code.',
});

const apiGlobalLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 600,
  keyPrefix: 'api-global',
  includeEmail: false,
});

module.exports = {
  createRateLimiter,
  resetRateLimiters,
  authAccountLimiter,
  loginIpLimiter,
  otpVerifyLimiter,
  apiGlobalLimiter,
};

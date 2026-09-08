const ApiError = require('../utils/ApiError');
const env = require('../config/env');

/**
 * Catches everything forwarded via next(err) (including from
 * asyncHandler). Always responds with the same shape:
 *   { error: true, message, code }
 * Never leaks stack traces or raw DB error messages in production —
 * per Phase 1 "Secure error handling" requirement.
 */
function errorMiddleware(err, req, res, next) { // eslint-disable-line no-unused-vars
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      error: true,
      message: err.message,
      code: err.code,
    });
  }

  // Postgres unique-violation, foreign-key-violation, etc. — surface as
  // 409/400 instead of a raw 500 with the driver's internal message.
  if (err.code === '23505') {
    return res.status(409).json({ error: true, message: 'Duplicate value', code: 'DUPLICATE' });
  }
  if (err.code === '23503') {
    return res
      .status(400)
      .json({ error: true, message: 'Related record not found', code: 'FK_VIOLATION' });
  }

  // eslint-disable-next-line no-console
  console.error(err);

  return res.status(500).json({
    error: true,
    message: env.nodeEnv === 'production' ? 'Internal server error' : err.message,
    code: 'INTERNAL_ERROR',
  });
}

function notFoundMiddleware(req, res) {
  res.status(404).json({ error: true, message: 'Route not found', code: 'NOT_FOUND' });
}

module.exports = { errorMiddleware, notFoundMiddleware };

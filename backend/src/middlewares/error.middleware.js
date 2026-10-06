const ApiError = require('../utils/ApiError');
const env = require('../config/env');

/**
 * Catches everything forwarded via next(err) (including from
 * asyncHandler).
 *
 * Always responds with the same shape:
 *   { error: true, message, code }
 *
 * Never exposes stack traces or raw internal error details through
 * the HTTP response in production.
 */
function errorMiddleware(err, req, res, next) { // eslint-disable-line no-unused-vars
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      error: true,
      message: err.message,
      code: err.code,
    });
  }

  /*
   * PostgreSQL unique-violation.
   *
   * Do not expose the driver's internal error message because it may
   * contain database-specific details.
   */
  if (err && err.code === '23505') {
    return res.status(409).json({
      error: true,
      message: 'Duplicate value',
      code: 'DUPLICATE',
    });
  }

  /*
   * PostgreSQL foreign-key violation.
   *
   * Keep the response generic so database internals are never exposed
   * to the client.
   */
  if (err && err.code === '23503') {
    return res.status(400).json({
      error: true,
      message: 'Related record not found',
      code: 'FK_VIOLATION',
    });
  }

  /*
   * PostgreSQL invalid input syntax (e.g. malformed UUID) or numeric overflow.
   * Return 400 Bad Request without leaking raw SQL/driver error details.
   */
  if (err && (err.code === '22P02' || err.code === '22003')) {
    return res.status(400).json({
      error: true,
      message: 'Invalid parameter format or numeric value out of range',
      code: 'VALIDATION_ERROR',
    });
  }

  /*
   * Unexpected errors.
   *
   * Development:
   *   Keep the original message to make local debugging easier.
   *
   * Production:
   *   Never expose internal error details to the client.
   */
  if (env.nodeEnv === 'production') {
    // eslint-disable-next-line no-console
    console.error('Unhandled server error:', {
      name: err?.name,
      message: err?.message,
      code: err?.code,
    });

    return res.status(500).json({
      error: true,
      message: 'Internal server error',
      code: 'INTERNAL_ERROR',
    });
  }

  // Development-only logging.
  // eslint-disable-next-line no-console
  console.error(err);

  return res.status(500).json({
    error: true,
    message: err?.message || 'Internal server error',
    code: 'INTERNAL_ERROR',
  });
}

function notFoundMiddleware(req, res) {
  return res.status(404).json({
    error: true,
    message: 'Route not found',
    code: 'NOT_FOUND',
  });
}

module.exports = {
  errorMiddleware,
  notFoundMiddleware,
};
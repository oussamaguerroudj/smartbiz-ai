/**
 * Uniform application error. Every module throws this (never a raw
 * Error) so the error middleware can always produce the same response
 * shape: { error, message, code }.
 */
class ApiError extends Error {
  constructor(statusCode, code, message, details = null) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details && typeof details === 'object' ? details : null;
  }

  static badRequest(message, code = 'BAD_REQUEST', details = null) {
    return new ApiError(400, code, message, details);
  }

  static unauthorized(message = 'Unauthorized', code = 'UNAUTHORIZED', details = null) {
    return new ApiError(401, code, message, details);
  }

  static forbidden(message = 'Forbidden', code = 'FORBIDDEN', details = null) {
    return new ApiError(403, code, message, details);
  }

  static notFound(message = 'Not found', code = 'NOT_FOUND', details = null) {
    return new ApiError(404, code, message, details);
  }

  static conflict(message, code = 'CONFLICT', details = null) {
    return new ApiError(409, code, message, details);
  }

  static tooManyRequests(message = 'Too many requests, please try again later', code = 'RATE_LIMIT_EXCEEDED', details = null) {
    return new ApiError(429, code, message, details);
  }

  static serviceUnavailable(message = 'Service unavailable', code = 'SERVICE_UNAVAILABLE', details = null) {
    return new ApiError(503, code, message, details);
  }

  static internal(message = 'Internal server error', code = 'INTERNAL_ERROR', details = null) {
    return new ApiError(500, code, message, details);
  }
}

module.exports = ApiError;

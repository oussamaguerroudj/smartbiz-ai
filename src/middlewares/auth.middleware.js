const jwt = require('jsonwebtoken');
const env = require('../config/env');
const ApiError = require('../utils/ApiError');

/**
 * Verifies the Bearer access token and attaches req.user = { id,
 * companyId, role }.
 *
 * CRITICAL (Phase 1, Multi-tenant Architecture §10): companyId is taken
 * ONLY from the verified JWT payload — never from req.body, req.query,
 * or any client-supplied field. Every downstream repository call uses
 * req.user.companyId as the tenant filter. This is enforcement layer #1
 * of 3 (the other two are the repository layer itself, and the security
 * tests planned for Phase 7).
 */
function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next(ApiError.unauthorized('Missing or malformed Authorization header'));
  }

  const token = header.slice('Bearer '.length);

  try {
    const payload = jwt.verify(token, env.jwt.accessSecret);
    req.user = {
      id: payload.sub,
      companyId: payload.companyId,
      role: payload.role,
    };
    return next();
  } catch (err) {
    return next(ApiError.unauthorized('Invalid or expired token'));
  }
}

/**
 * Restricts a route to specific roles. Use AFTER authMiddleware.
 * Example: router.delete('/employees/:id', authMiddleware, requireRole('owner'), ...)
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(ApiError.forbidden('Insufficient permissions for this action'));
    }
    return next();
  };
}

module.exports = { authMiddleware, requireRole };

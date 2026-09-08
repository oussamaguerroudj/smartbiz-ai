const jwt = require('jsonwebtoken');
const env = require('../config/env');
const ApiError = require('../utils/ApiError');

/**
 * Verifies the Bearer access token and attaches req.user.
 *
 * companyId is taken only from the verified JWT payload.
 *
 * NOTE: there's no unverified-email gate here anymore. Accounts are only
 * ever created (see auth.service.js#verifyEmail) after the emailed code
 * is confirmed, so by construction every user row — and therefore every
 * access token ever issued — belongs to an already-verified account.
 */
function authMiddleware(req, res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return next(
      ApiError.unauthorized('Missing or malformed Authorization header'),
    );
  }

  const token = header.slice('Bearer '.length);

  try {
    const payload = jwt.verify(token, env.jwt.accessSecret);

    req.user = {
      id: payload.sub,
      companyId: payload.companyId,
      role: payload.role,
      emailVerified: payload.emailVerified === true,
    };

    return next();
  } catch (err) {
    return next(ApiError.unauthorized('Invalid or expired token'));
  }
}

/**
 * Restricts a route to specific roles.
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(
        ApiError.forbidden('Insufficient permissions for this action'),
      );
    }

    return next();
  };
}

module.exports = {
  authMiddleware,
  requireRole,
};

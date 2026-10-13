const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { query } = require('../config/db');
const subscriptionConfig = require('../config/subscription');
const ApiError = require('../utils/ApiError');

const APPEAL_TOKEN_EXPIRES_IN = '7d';

/**
 * Signs a narrowly scoped JWT (`type: 'appeal'`) that can ONLY be used on
 * `/api/support/appeal` and `/api/support/appeal/status`.
 * Normal protected routes (`authMiddleware`) reject `type: 'appeal'` with 401.
 */
function signAppealToken({ userId, companyId, role = 'owner' }) {
  return jwt.sign(
    {
      sub: userId,
      companyId,
      role,
      type: 'appeal',
    },
    env.jwt.accessSecret,
    {
      algorithm: 'HS256',
      expiresIn: APPEAL_TOKEN_EXPIRES_IN,
    },
  );
}

/**
 * Builds the canonical structured details payload for `ACCOUNT_SUSPENDED`.
 */
function buildSuspendedDetails(row) {
  const userId = row.user_id || row.id;
  const companyId = row.company_id || row.comp_id;
  const userRole = row.user_role || row.role || 'owner';
  const reason =
    (typeof row.suspension_reason === 'string' && row.suspension_reason.trim())
      ? row.suspension_reason.trim()
      : 'Your account has been suspended by the administrator.';

  const appealToken = userId && companyId
    ? signAppealToken({ userId, companyId, role: userRole })
    : null;

  return {
    accountStatus: 'suspended',
    isSuspended: true,
    suspensionReason: reason,
    suspendedAt: row.suspended_at || null,
    appealToken,
    user: {
      id: userId,
      companyId,
      name: row.user_name || row.name || null,
      email: row.user_email || row.email || null,
    },
    company: {
      id: companyId,
      name: row.company_name || null,
    },
    supportContact: {
      email: subscriptionConfig.business.email,
      phone: subscriptionConfig.business.phoneDisplay,
      whatsappUrl: subscriptionConfig.business.whatsappUrl,
    },
  };
}

/**
 * Evaluates whether a company row's trial or temporary license has expired.
 */
function evaluateExpirationState(row) {
  const now = new Date();
  const type = row.entitlement_type || 'none';

  if (type === 'trial' && row.trial_ends_at) {
    const endsAt = new Date(row.trial_ends_at);
    if (now > endsAt) {
      return {
        isExpired: true,
        status: 'expired_trial',
        expiresAt: row.trial_ends_at,
        message:
          'Your 15-day free trial has ended. Activate a lifetime license or contact the administrator to continue using Modiri AI.',
      };
    }
  }

  if (type === 'temporary' && row.license_expires_at) {
    const endsAt = new Date(row.license_expires_at);
    if (now > endsAt) {
      return {
        isExpired: true,
        status: 'expired_temporary',
        expiresAt: row.license_expires_at,
        message:
          'Your temporary license has expired. Please renew or upgrade to a lifetime license to continue using Modiri AI.',
      };
    }
  }

  if (type === 'expired') {
    return {
      isExpired: true,
      status: 'expired_trial',
      expiresAt: row.trial_ends_at || row.license_expires_at || null,
      message:
        'Your trial or license has expired. Please activate a license to continue using Modiri AI.',
    };
  }

  return { isExpired: false, status: type, expiresAt: null, message: null };
}

function buildTrialExpiredDetails(row, expState) {
  const userId = row.user_id || row.id;
  const companyId = row.company_id || row.comp_id;

  return {
    accountStatus: expState.status,
    entitlementType: row.entitlement_type || 'trial',
    trialStartsAt: row.trial_starts_at || null,
    trialEndsAt: row.trial_ends_at || null,
    licenseExpiresAt: row.license_expires_at || null,
    expiresAt: expState.expiresAt,
    user: {
      id: userId,
      companyId,
      name: row.user_name || row.name || null,
      email: row.user_email || row.email || null,
    },
    company: {
      id: companyId,
      name: row.company_name || null,
    },
    product: {
      name: subscriptionConfig.product.name,
      price: subscriptionConfig.product.priceDzd,
      currency: subscriptionConfig.product.currency,
    },
    supportContact: {
      email: subscriptionConfig.business.email,
      phone: subscriptionConfig.business.phoneDisplay,
      whatsappUrl: subscriptionConfig.business.whatsappUrl,
      ccpAccount: subscriptionConfig.business.ccpAccount,
      ownerName: subscriptionConfig.business.ownerName,
      ownerNameAr: subscriptionConfig.business.ownerNameAr,
    },
  };
}

/**
 * Checks whether an incoming request is on the strict allowlist of routes
 * accessible when a company's trial or temporary license has expired
 * (so the user can view their entitlement status, purchase a license via
 * Chargily or manual CCP, or contact support).
 * All business data and sync routes return false and are blocked with 403 TRIAL_EXPIRED.
 */
function isAllowedWhenTrialExpired(req) {
  const fullPath = (req.originalUrl || req.baseUrl || req.url || '').split('?')[0];
  const method = (req.method || 'GET').toUpperCase();

  if (fullPath.startsWith('/api/subscriptions')) {
    // Allow reading entitlement/product status; block restarting trial when expired
    if (fullPath.includes('/select-trial')) {
      return false;
    }
    return true;
  }

  if (fullPath.startsWith('/api/payments')) {
    return true;
  }

  if (fullPath.startsWith('/api/support')) {
    return true;
  }

  if (
    method === 'GET' &&
    (fullPath === '/api/auth/profile' ||
      fullPath === '/api/auth/me' ||
      fullPath === '/api/companies/me')
  ) {
    return true;
  }

  return false;
}

/**
 * Verifies the Bearer access token and validates live account & company status
 * against PostgreSQL on every protected request.
 */
function authMiddleware(req, res, next) {
  const header = req.headers && req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next(ApiError.unauthorized('Missing or malformed Authorization header'));
  }

  const token = header.slice('Bearer '.length);

  let payload;
  try {
    payload = jwt.verify(token, env.jwt.accessSecret, {
      algorithms: ['HS256'],
    });
  } catch (err) {
    return next(ApiError.unauthorized('Invalid or expired token'));
  }

  if (payload.type && payload.type !== 'access') {
    return next(ApiError.unauthorized('Invalid token type'));
  }
  if (!payload.sub || !payload.companyId) {
    return next(ApiError.unauthorized('Invalid token payload'));
  }

  // Authoritative database check for user and company state
  return Promise.resolve()
    .then(async () => {
      const dbRes = await query(
        `SELECT
           u.id AS user_id,
           u.company_id,
           u.name AS user_name,
           u.email AS user_email,
           u.phone AS user_phone,
           u.role AS user_role,
           u.email_verified,
           u.deleted_at,
           c.id AS comp_id,
           c.name AS company_name,
           c.business_type,
           c.onboarding_completed,
           c.entitlement_type,
           c.trial_starts_at,
           c.trial_ends_at,
           c.license_expires_at,
           c.account_approval_status,
           c.is_suspended,
           c.suspension_reason,
           c.suspended_at
         FROM users u
         LEFT JOIN companies c ON c.id = u.company_id
         WHERE u.id = $1
         LIMIT 1`,
        [payload.sub],
      );

      const row = dbRes && Array.isArray(dbRes.rows) ? dbRes.rows[0] : null;
      if (!row || row.deleted_at !== null) {
        return next(
          ApiError.unauthorized('Your session is no longer valid.', 'SESSION_REVOKED'),
        );
      }

      if (!row.comp_id || row.company_id !== payload.companyId) {
        return next(
          ApiError.unauthorized('Company session is no longer valid.', 'SESSION_REVOKED'),
        );
      }

      if (row.email_verified === false) {
        return next(
          ApiError.forbidden(
            'Please verify your email address before continuing.',
            'EMAIL_NOT_VERIFIED',
          ),
        );
      }

      // 1. Authoritative Account Suspension Enforcement
      if (row.is_suspended === true && row.user_role !== 'super_admin') {
        const suspendedDetails = buildSuspendedDetails(row);
        return next(
          ApiError.forbidden(
            suspendedDetails.suspensionReason,
            'ACCOUNT_SUSPENDED',
            suspendedDetails,
          ),
        );
      }

      // 2. Authoritative Trial / Temporary License Expiration Enforcement
      if (row.user_role !== 'super_admin' && row.user_role !== 'support') {
        const expState = evaluateExpirationState(row);
        if (expState.isExpired && !isAllowedWhenTrialExpired(req)) {
          const expiredDetails = buildTrialExpiredDetails(row, expState);
          return next(
            ApiError.forbidden(
              expState.message,
              'TRIAL_EXPIRED',
              expiredDetails,
            ),
          );
        }
      }

      req.user = {
        id: row.user_id,
        companyId: row.company_id,
        role: row.user_role,
        email: row.user_email,
        name: row.user_name,
      };

      req.company = {
        id: row.comp_id,
        name: row.company_name,
        businessType: row.business_type,
        onboardingCompleted: row.onboarding_completed === true,
        entitlementType: row.entitlement_type || 'none',
        isSuspended: row.is_suspended === true,
      };

      return next();
    })
    .catch((err) => next(err));
}

/**
 * Narrowly scoped authentication middleware strictly for suspended user appeals
 * (`POST /api/support/appeal` and `GET /api/support/appeal/status`).
 * Accepts either a dedicated `appeal` token (`type: 'appeal'`) or an `access`
 * token belonging to the user, verifies the user and company in PostgreSQL,
 * and populates `req.appealContext`. Never grants access to business endpoints.
 */
function appealAuthMiddleware(req, res, next) {
  const header = req.headers && req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return next(
      ApiError.unauthorized(
        'Authentication is required to submit or view an account appeal.',
        'APPEAL_AUTH_REQUIRED',
      ),
    );
  }

  const token = header.slice('Bearer '.length);

  let payload;
  try {
    payload = jwt.verify(token, env.jwt.accessSecret, {
      algorithms: ['HS256'],
    });
  } catch (err) {
    return next(
      ApiError.unauthorized(
        'Your appeal session has expired. Please sign in again to submit an appeal.',
        'APPEAL_TOKEN_EXPIRED',
      ),
    );
  }

  if (payload.type !== 'appeal' && payload.type !== 'access') {
    return next(ApiError.unauthorized('Invalid token type for appeal', 'INVALID_TOKEN_TYPE'));
  }

  if (!payload.sub || !payload.companyId) {
    return next(ApiError.unauthorized('Invalid token payload', 'UNAUTHORIZED'));
  }

  return Promise.resolve()
    .then(async () => {
      const dbRes = await query(
        `SELECT
           u.id AS user_id,
           u.company_id,
           u.name AS user_name,
           u.email AS user_email,
           u.phone AS user_phone,
           u.role AS user_role,
           u.deleted_at,
           c.id AS comp_id,
           c.name AS company_name,
           c.is_suspended,
           c.suspension_reason,
           c.suspended_at,
           c.entitlement_type,
           c.trial_ends_at,
           c.license_expires_at
         FROM users u
         INNER JOIN companies c ON c.id = u.company_id
         WHERE u.id = $1 AND c.id = $2
         LIMIT 1`,
        [payload.sub, payload.companyId],
      );

      const row = dbRes && Array.isArray(dbRes.rows) ? dbRes.rows[0] : null;
      if (!row || row.deleted_at !== null) {
        return next(
          ApiError.unauthorized('Account no longer exists.', 'SESSION_REVOKED'),
        );
      }

      req.appealContext = {
        userId: row.user_id,
        companyId: row.company_id,
        role: row.user_role,
        name: row.user_name,
        email: row.user_email,
        phone: row.user_phone || null,
        companyName: row.company_name,
        isSuspended: row.is_suspended === true,
        suspensionReason: row.suspension_reason || null,
        suspendedAt: row.suspended_at || null,
        entitlementType: row.entitlement_type || 'none',
      };

      return next();
    })
    .catch((err) => next(err));
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

module.exports = {
  authMiddleware,
  appealAuthMiddleware,
  requireRole,
  signAppealToken,
  buildSuspendedDetails,
  evaluateExpirationState,
  buildTrialExpiredDetails,
};


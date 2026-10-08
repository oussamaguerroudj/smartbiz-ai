const { query } = require('../config/db');
const ApiError = require('../utils/ApiError');

/**
 * Restricts a specialized-module router (clinic, restaurant, pharmacy,
 * ...) to companies whose `business_type` actually matches. Use AFTER
 * authMiddleware.
 *
 * Why this exists (Clinic audit, Ch. 21 "Security and Data Isolation"):
 * authMiddleware only proves WHO the caller is and WHICH company they
 * belong to  -  it never checked WHAT KIND of company that is. Every
 * specialized router (e.g. clinic.routes.js) was reachable by any
 * authenticated user of ANY company type, so a restaurant account could
 * call /clinic/patients and read/write clinic data structurally (every
 * query is still correctly scoped to req.user.companyId, so this was
 * never a cross-TENANT leak  -  but a restaurant account has no clinic_*
 * rows of its own, so in practice it could only create nonsensical data
 * for itself, not read anyone else's; it was still the wrong module for
 * that account and worth closing off).
 *
 * companyId comes only from the verified JWT (auth.middleware's own
 * guarantee)  -  this middleware just adds one more read of that same
 * company's declared type before letting the request through.
 */
function requireBusinessType(...allowedTypes) {
  return async (req, res, next) => {
    try {
      const result = await query(
        `SELECT business_type FROM companies WHERE id = $1`,
        [req.user.companyId],
      );
      const company = result.rows[0];
      if (!company) {
        return next(ApiError.notFound('Company not found'));
      }
      if (!company.business_type || !allowedTypes.includes(company.business_type)) {
        return next(
          ApiError.forbidden(
            'This feature is not available for your business type',
            'BUSINESS_TYPE_NOT_ALLOWED',
          ),
        );
      }
      return next();
    } catch (err) {
      return next(err);
    }
  };
}

module.exports = { requireBusinessType };

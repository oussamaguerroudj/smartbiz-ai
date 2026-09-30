const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware } = require('../../middlewares/auth.middleware');

/**
 * Companies — one row per tenant.
 *
 * The authenticated user's companyId is always taken from the
 * verified JWT through req.user.companyId.
 *
 * IMPORTANT:
 * Never accept companyId from req.body, req.query, or req.params.
 */
// Ch. 1/16 — SPECIALIZED BUSINESS CONTENT: matches business_type_enum
// after migration 016. Every value here works fully at the CORE level
// regardless of whether a dedicated specialized module (clinic_*,
// restaurant_*, ...) exists for it yet — see backend/SPECIALIZED_MODULES.md
// for which verticals currently have one.
const VALID_TYPES = [
  'clothing',
  'grocery',
  'pharmacy',
  'clinic',
  'restaurant',
  'company',
  'workshop',
  'retail_store',
  'cafe',
  'beauty_salon',
  'barbershop',
  'gym',
  'hotel',
  'dental_clinic',
  'medical_laboratory',
  'car_repair',
  'electronics_store',
  'supermarket',
  'bakery',
  'law_office',
  'accounting_office',
  'real_estate_agency',
  'education_center',
  'other',
];

const COMPANY_SELECT = `
  id,
  name,
  business_type,
  currency,
  phone,
  address,
  created_at,
  updated_at
`;

function validateOptionalString(value, fieldName, { minLength = 1, maxLength = 255 } = {}) {
  if (value === undefined) {
    return;
  }

  if (typeof value !== 'string') {
    throw ApiError.badRequest(
      `${fieldName} must be a string`,
      'VALIDATION_ERROR',
    );
  }

  const trimmed = value.trim();

  if (trimmed.length < minLength) {
    throw ApiError.badRequest(
      `${fieldName} must be at least ${minLength} character${minLength === 1 ? '' : 's'}`,
      'VALIDATION_ERROR',
    );
  }

  if (trimmed.length > maxLength) {
    throw ApiError.badRequest(
      `${fieldName} must not exceed ${maxLength} characters`,
      'VALIDATION_ERROR',
    );
  }
}

const getMe = asyncHandler(async (req, res) => {
  const result = await query(
    `SELECT ${COMPANY_SELECT}
     FROM companies
     WHERE id = $1`,
    [req.user.companyId],
  );

  if (!result.rows[0]) {
    throw ApiError.notFound('Company not found');
  }

  return res.json({
    data: result.rows[0],
  });
});

const updateMe = asyncHandler(async (req, res) => {
  const body = req.body || {};

  const {
    name,
    businessType,
    currency,
    phone,
    address,
  } = body;

  /*
   * Validate only fields that are actually supplied.
   */
  validateOptionalString(name, 'name', {
    minLength: 2,
    maxLength: 255,
  });

  validateOptionalString(currency, 'currency', {
    minLength: 1,
    maxLength: 10,
  });

  validateOptionalString(phone, 'phone', {
    minLength: 3,
    maxLength: 50,
  });

  validateOptionalString(address, 'address', {
    minLength: 1,
    maxLength: 500,
  });

  if (
    businessType !== undefined &&
    (typeof businessType !== 'string' ||
      !VALID_TYPES.includes(businessType.trim()))
  ) {
    throw ApiError.badRequest(
      `businessType must be one of: ${VALID_TYPES.join(', ')}`,
      'VALIDATION_ERROR',
    );
  }

  const result = await query(
    `UPDATE companies
     SET
       name = COALESCE($2, name),
       business_type = COALESCE($3, business_type),
       currency = COALESCE($4, currency),
       phone = COALESCE($5, phone),
       address = COALESCE($6, address)
     WHERE id = $1
     RETURNING ${COMPANY_SELECT}`,
    [
      req.user.companyId,
      name === undefined ? null : name.trim(),
      businessType === undefined ? null : businessType.trim(),
      currency === undefined ? null : currency.trim(),
      phone === undefined ? null : phone.trim(),
      address === undefined ? null : address.trim(),
    ],
  );

  if (!result.rows[0]) {
    throw ApiError.notFound('Company not found');
  }

  return res.json({
    data: result.rows[0],
  });
});

const router = express.Router();

/*
 * All company endpoints are tenant-scoped through req.user.companyId.
 */
router.use(authMiddleware);

router.get('/me', getMe);
router.put('/me', updateMe);

module.exports = router;
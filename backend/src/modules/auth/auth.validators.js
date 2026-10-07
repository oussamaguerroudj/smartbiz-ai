const ApiError = require('../../utils/ApiError');

const EMAIL_REGEX = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function isValidEmail(email) {
  return typeof email === 'string' && EMAIL_REGEX.test(email.trim());
}

function isValidPassword(password) {
  return typeof password === 'string' && password.length >= 6;
}

function isValidVerificationCode(code) {
  return /^\d{6}$/.test(String(code));
}

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

const VALID_INDUSTRIES = [
  'retail',
  'services',
  'healthcare',
  'food_beverage',
  'hospitality',
  'education',
  'construction',
  'technology',
  'manufacturing',
  'other',
];

function validateRegister(req, res, next) {
  const { name, email, password, industry, type } = req.body || {};

  if (typeof name !== 'string' || name.trim().length < 2) {
    return next(
      ApiError.badRequest(
        'name must be at least 2 characters',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!isValidEmail(email)) {
    return next(
      ApiError.badRequest(
        'A valid email is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!isValidPassword(password)) {
    return next(
      ApiError.badRequest(
        'password must be at least 6 characters',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    industry !== undefined &&
    industry !== null &&
    (typeof industry !== 'string' ||
      (industry.trim().length > 0 &&
        !VALID_INDUSTRIES.includes(industry.trim().toLowerCase())))
  ) {
    return next(
      ApiError.badRequest(
        `industry must be one of: ${VALID_INDUSTRIES.join(', ')}`,
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    type !== undefined &&
    type !== null &&
    (typeof type !== 'string' ||
      (type.trim().length > 0 &&
        !VALID_TYPES.includes(type.trim().toLowerCase())))
  ) {
    return next(
      ApiError.badRequest(
        `type must be one of: ${VALID_TYPES.join(', ')}`,
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateLogin(req, res, next) {
  const { email, password } = req.body || {};

  if (!isValidEmail(email)) {
    return next(
      ApiError.badRequest(
        'A valid email is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (typeof password !== 'string' || password.length === 0) {
    return next(
      ApiError.badRequest(
        'password is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateRefresh(req, res, next) {
  const { refreshToken } = req.body || {};

  if (typeof refreshToken !== 'string' || refreshToken.trim().length === 0) {
    return next(
      ApiError.badRequest(
        'refreshToken is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateVerifyEmail(req, res, next) {
  const { email, code } = req.body || {};

  if (!isValidEmail(email)) {
    return next(
      ApiError.badRequest(
        'A valid email is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!isValidVerificationCode(code)) {
    return next(
      ApiError.badRequest(
        'code must be a 6-digit number',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateResendVerification(req, res, next) {
  const { email } = req.body || {};

  if (!isValidEmail(email)) {
    return next(
      ApiError.badRequest(
        'A valid email is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateForgotPassword(req, res, next) {
  const { email } = req.body || {};

  if (!isValidEmail(email)) {
    return next(
      ApiError.badRequest(
        'A valid email is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateResetPassword(req, res, next) {
  const { email, code, newPassword } = req.body || {};

  if (!isValidEmail(email)) {
    return next(
      ApiError.badRequest(
        'A valid email is required',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!isValidVerificationCode(code)) {
    return next(
      ApiError.badRequest(
        'code must be a 6-digit number',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!isValidPassword(newPassword)) {
    return next(
      ApiError.badRequest(
        'newPassword must be at least 6 characters',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

module.exports = {
  validateRegister,
  validateLogin,
  validateRefresh,
  validateVerifyEmail,
  validateResendVerification,
  validateForgotPassword,
  validateResetPassword,
  VALID_INDUSTRIES,
  VALID_TYPES,
};
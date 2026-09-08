const ApiError = require('../../utils/ApiError');

const EMAIL_REGEX = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function validateRegister(req, res, next) {
  const { name, email, password } = req.body;
  if (!name || typeof name !== 'string' || name.trim().length < 2) {
    return next(ApiError.badRequest('name must be at least 2 characters', 'VALIDATION_ERROR'));
  }
  if (!email || !EMAIL_REGEX.test(email)) {
    return next(ApiError.badRequest('A valid email is required', 'VALIDATION_ERROR'));
  }
  if (!password || password.length < 6) {
    return next(ApiError.badRequest('password must be at least 6 characters', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateLogin(req, res, next) {
  const { email, password } = req.body;
  if (!email || !EMAIL_REGEX.test(email)) {
    return next(ApiError.badRequest('A valid email is required', 'VALIDATION_ERROR'));
  }
  if (!password) {
    return next(ApiError.badRequest('password is required', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateRefresh(req, res, next) {
  if (!req.body.refreshToken) {
    return next(ApiError.badRequest('refreshToken is required', 'VALIDATION_ERROR'));
  }
  return next();
}

module.exports = { validateRegister, validateLogin, validateRefresh };

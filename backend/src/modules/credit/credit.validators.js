const ApiError = require('../../utils/ApiError');

function validateCreatePurchase(req, res, next) {
  const { customerId, items } = req.body || {};

  if (typeof customerId !== 'string' || customerId.trim().length === 0) {
    return next(ApiError.badRequest('customerId is required', 'VALIDATION_ERROR'));
  }

  if (!Array.isArray(items) || items.length === 0) {
    return next(ApiError.badRequest('items must be a non-empty array', 'VALIDATION_ERROR'));
  }

  return next();
}

function validateRecordPayment(req, res, next) {
  const { customerId, amount } = req.body || {};

  if (typeof customerId !== 'string' || customerId.trim().length === 0) {
    return next(ApiError.badRequest('customerId is required', 'VALIDATION_ERROR'));
  }

  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    return next(ApiError.badRequest('amount must be a positive number', 'VALIDATION_ERROR'));
  }

  return next();
}

module.exports = {
  validateCreatePurchase,
  validateRecordPayment,
};

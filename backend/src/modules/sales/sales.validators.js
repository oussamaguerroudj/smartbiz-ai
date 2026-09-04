const ApiError = require('../../utils/ApiError');

function validateCreateSale(req, res, next) {
  const { items, discount, paymentStatus } = req.body;

  if (!Array.isArray(items) || items.length === 0) {
    return next(ApiError.badRequest('items must be a non-empty array', 'VALIDATION_ERROR'));
  }
  for (const item of items) {
    if (!item.productId || typeof item.productId !== 'string') {
      return next(ApiError.badRequest('Each item requires a productId', 'VALIDATION_ERROR'));
    }
    if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
      return next(ApiError.badRequest('Each item requires a positive integer quantity', 'VALIDATION_ERROR'));
    }
  }
  if (discount !== undefined && (typeof discount !== 'number' || discount < 0)) {
    return next(ApiError.badRequest('discount must be ≥ 0', 'VALIDATION_ERROR'));
  }
  if (paymentStatus !== undefined && !['paid', 'unpaid', 'partial'].includes(paymentStatus)) {
    return next(ApiError.badRequest('paymentStatus must be paid, unpaid, or partial', 'VALIDATION_ERROR'));
  }
  return next();
}

module.exports = { validateCreateSale };

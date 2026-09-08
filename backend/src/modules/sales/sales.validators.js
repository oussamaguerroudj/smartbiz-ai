const ApiError = require('../../utils/ApiError');

const VALID_PAYMENT_STATUSES = ['paid', 'unpaid'];

function validateCreateSale(req, res, next) {
  const {
    items,
    discount,
    paymentStatus = 'paid',
  } = req.body || {};

  if (!Array.isArray(items) || items.length === 0) {
    return next(
      ApiError.badRequest(
        'items must be a non-empty array',
        'VALIDATION_ERROR',
      ),
    );
  }

  const productIds = new Set();

  for (const item of items) {
    if (
      !item ||
      typeof item.productId !== 'string' ||
      item.productId.trim().length === 0
    ) {
      return next(
        ApiError.badRequest(
          'Each item requires a valid productId',
          'VALIDATION_ERROR',
        ),
      );
    }

    if (
      !Number.isInteger(item.quantity) ||
      item.quantity <= 0
    ) {
      return next(
        ApiError.badRequest(
          'Each item requires a positive integer quantity',
          'VALIDATION_ERROR',
        ),
      );
    }

    if (productIds.has(item.productId)) {
      return next(
        ApiError.badRequest(
          `Product ${item.productId} appears more than once in the sale`,
          'DUPLICATE_PRODUCT',
        ),
      );
    }

    productIds.add(item.productId);
  }

  if (
    discount !== undefined &&
    (
      typeof discount !== 'number' ||
      !Number.isFinite(discount) ||
      discount < 0
    )
  ) {
    return next(
      ApiError.badRequest(
        'discount must be a non-negative number',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!VALID_PAYMENT_STATUSES.includes(paymentStatus)) {
    return next(
      ApiError.badRequest(
        `paymentStatus must be one of: ${VALID_PAYMENT_STATUSES.join(', ')}`,
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

module.exports = {
  validateCreateSale,
};
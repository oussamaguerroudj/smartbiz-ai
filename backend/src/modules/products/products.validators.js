const ApiError = require('../../utils/ApiError');

function isFiniteNonNegativeNumber(value) {
  return (
    typeof value === 'number' &&
    Number.isFinite(value) &&
    value >= 0
  );
}

function validateCreate(req, res, next) {
  const {
    name,
    purchasePrice,
    sellingPrice,
    quantity,
    minimumStock,
  } = req.body || {};

  if (
    typeof name !== 'string' ||
    name.trim().length < 2
  ) {
    return next(
      ApiError.badRequest(
        'name must be at least 2 characters',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (name.trim().length > 255) {
    return next(
      ApiError.badRequest(
        'name must not exceed 255 characters',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!isFiniteNonNegativeNumber(purchasePrice)) {
    return next(
      ApiError.badRequest(
        'purchasePrice must be a non-negative finite number',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (!isFiniteNonNegativeNumber(sellingPrice)) {
    return next(
      ApiError.badRequest(
        'sellingPrice must be a non-negative finite number',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    quantity !== undefined &&
    (
      !Number.isInteger(quantity) ||
      quantity < 0
    )
  ) {
    return next(
      ApiError.badRequest(
        'quantity must be a non-negative integer',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    minimumStock !== undefined &&
    (
      !Number.isInteger(minimumStock) ||
      minimumStock < 0
    )
  ) {
    return next(
      ApiError.badRequest(
        'minimumStock must be a non-negative integer',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateUpdate(req, res, next) {
  const {
    name,
    purchasePrice,
    sellingPrice,
    quantity,
    minimumStock,
  } = req.body || {};

  if (
    name !== undefined &&
    (
      typeof name !== 'string' ||
      name.trim().length < 2 ||
      name.trim().length > 255
    )
  ) {
    return next(
      ApiError.badRequest(
        'name must be between 2 and 255 characters',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    purchasePrice !== undefined &&
    !isFiniteNonNegativeNumber(purchasePrice)
  ) {
    return next(
      ApiError.badRequest(
        'purchasePrice must be a non-negative finite number',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    sellingPrice !== undefined &&
    !isFiniteNonNegativeNumber(sellingPrice)
  ) {
    return next(
      ApiError.badRequest(
        'sellingPrice must be a non-negative finite number',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    quantity !== undefined &&
    (
      !Number.isInteger(quantity) ||
      quantity < 0
    )
  ) {
    return next(
      ApiError.badRequest(
        'quantity must be a non-negative integer',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (
    minimumStock !== undefined &&
    (
      !Number.isInteger(minimumStock) ||
      minimumStock < 0
    )
  ) {
    return next(
      ApiError.badRequest(
        'minimumStock must be a non-negative integer',
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

module.exports = {
  validateCreate,
  validateUpdate,
};
const ApiError = require('../../utils/ApiError');

function validateCreate(req, res, next) {
  const { name, purchasePrice, sellingPrice } = req.body;
  if (!name || typeof name !== 'string' || name.trim().length < 2) {
    return next(ApiError.badRequest('name must be at least 2 characters', 'VALIDATION_ERROR'));
  }
  if (purchasePrice === undefined || typeof purchasePrice !== 'number') {
    return next(ApiError.badRequest('purchasePrice is required and must be a number', 'VALIDATION_ERROR'));
  }
  if (sellingPrice === undefined || typeof sellingPrice !== 'number') {
    return next(ApiError.badRequest('sellingPrice is required and must be a number', 'VALIDATION_ERROR'));
  }
  return next();
}

module.exports = { validateCreate };

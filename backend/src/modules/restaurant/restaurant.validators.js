const ApiError = require('../../utils/ApiError');

function validateCreateTable(req, res, next) {
  const { name } = req.body || {};
  if (typeof name !== 'string' || name.trim().length === 0) {
    return next(ApiError.badRequest('name is required', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateCreateMenuItem(req, res, next) {
  const { name } = req.body || {};
  if (typeof name !== 'string' || name.trim().length === 0) {
    return next(ApiError.badRequest('name is required', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateCreateOrder(req, res, next) {
  const { items } = req.body || {};
  if (!Array.isArray(items) || items.length === 0) {
    return next(ApiError.badRequest('items must be a non-empty array', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateCreateReservation(req, res, next) {
  const { customerName, reservedAt } = req.body || {};
  if (typeof customerName !== 'string' || customerName.trim().length === 0) {
    return next(ApiError.badRequest('customerName is required', 'VALIDATION_ERROR'));
  }
  if (!reservedAt || Number.isNaN(new Date(reservedAt).getTime())) {
    return next(ApiError.badRequest('reservedAt must be a valid date/time', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateRecordPayment(req, res, next) {
  const { amount } = req.body || {};
  if (typeof amount !== 'number' || Number.isNaN(amount) || amount <= 0) {
    return next(ApiError.badRequest('amount must be a positive number', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateCreateInventoryItem(req, res, next) {
  const { name } = req.body || {};
  if (typeof name !== 'string' || name.trim().length === 0) {
    return next(ApiError.badRequest('name is required', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateAdjustInventory(req, res, next) {
  const { movementType, quantityChange } = req.body || {};
  if (typeof movementType !== 'string') {
    return next(ApiError.badRequest('movementType is required', 'VALIDATION_ERROR'));
  }
  if (typeof quantityChange !== 'number' || Number.isNaN(quantityChange) || quantityChange === 0) {
    return next(ApiError.badRequest('quantityChange must be a non-zero number', 'VALIDATION_ERROR'));
  }
  return next();
}

module.exports = {
  validateCreateTable,
  validateCreateMenuItem,
  validateCreateOrder,
  validateCreateReservation,
  validateRecordPayment,
  validateCreateInventoryItem,
  validateAdjustInventory,
};

const ApiError = require('../../utils/ApiError');

function validateCreatePatient(req, res, next) {
  const fullName = (req.body?.fullName || req.body?.name || '').trim();
  if (!fullName) {
    return next(ApiError.badRequest('fullName is required', 'VALIDATION_ERROR'));
  }
  req.body.fullName = fullName;
  return next();
}

function validateCreateAppointment(req, res, next) {
  const { patientId, scheduledAt } = req.body || {};
  if (typeof patientId !== 'string' || patientId.trim().length === 0) {
    return next(ApiError.badRequest('patientId is required', 'VALIDATION_ERROR'));
  }
  if (!scheduledAt || Number.isNaN(new Date(scheduledAt).getTime())) {
    return next(ApiError.badRequest('scheduledAt must be a valid date/time', 'VALIDATION_ERROR'));
  }
  return next();
}

function validateAddToQueue(req, res, next) {
  const { patientId } = req.body || {};
  if (typeof patientId !== 'string' || patientId.trim().length === 0) {
    return next(ApiError.badRequest('patientId is required', 'VALIDATION_ERROR'));
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

function validateCreatePrescription(req, res, next) {
  const { patientId, items } = req.body || {};
  if (typeof patientId !== 'string' || patientId.trim().length === 0) {
    return next(ApiError.badRequest('patientId is required', 'VALIDATION_ERROR'));
  }
  if (!Array.isArray(items) || items.length === 0) {
    return next(ApiError.badRequest('At least one medication item is required', 'VALIDATION_ERROR'));
  }
  for (const item of items) {
    if (!item || typeof item.medicationName !== 'string' || !item.medicationName.trim()) {
      return next(ApiError.badRequest('Each item requires a medicationName', 'VALIDATION_ERROR'));
    }
  }
  return next();
}

function validateAddDocument(req, res, next) {
  const { patientId, fileName, fileBase64, mimeType } = req.body || {};
  if (typeof patientId !== 'string' || patientId.trim().length === 0) {
    return next(ApiError.badRequest('patientId is required', 'VALIDATION_ERROR'));
  }
  if (typeof fileName !== 'string' || fileName.trim().length === 0) {
    return next(ApiError.badRequest('fileName is required', 'VALIDATION_ERROR'));
  }
  if (typeof fileBase64 !== 'string' || fileBase64.length === 0) {
    return next(ApiError.badRequest('fileBase64 is required', 'VALIDATION_ERROR'));
  }
  if (typeof mimeType !== 'string' || mimeType.trim().length === 0) {
    return next(ApiError.badRequest('mimeType is required', 'VALIDATION_ERROR'));
  }
  return next();
}

module.exports = {
  validateCreatePatient,
  validateCreateAppointment,
  validateAddToQueue,
  validateRecordPayment,
  validateCreatePrescription,
  validateAddDocument,
};

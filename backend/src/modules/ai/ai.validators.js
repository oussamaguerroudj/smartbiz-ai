const ApiError = require('../../utils/ApiError');

// ~6MB of base64 text (~4.5MB decoded)  -  comfortably fits a real phone
// photo (especially since the client compresses before sending) while
// still bounding the worst case for both the request body and the
// self-hosted inference server's GPU queue.
const MAX_BASE64_IMAGE_LENGTH = 6 * 1024 * 1024;
const MAX_CHAT_MESSAGE_LENGTH = 2000;

function validateScanInvoice(req, res, next) {
  const { imageBase64 } = req.body || {};

  if (typeof imageBase64 !== 'string' || imageBase64.trim().length === 0) {
    return next(
      ApiError.badRequest('imageBase64 is required', 'VALIDATION_ERROR'),
    );
  }

  if (imageBase64.length > MAX_BASE64_IMAGE_LENGTH) {
    return next(
      ApiError.badRequest('Image is too large', 'VALIDATION_ERROR'),
    );
  }

  return next();
}

function validateChat(req, res, next) {
  const { message } = req.body || {};

  if (typeof message !== 'string' || message.trim().length === 0) {
    return next(
      ApiError.badRequest('message is required', 'VALIDATION_ERROR'),
    );
  }

  if (message.length > MAX_CHAT_MESSAGE_LENGTH) {
    return next(
      ApiError.badRequest(
        `message is too long (max ${MAX_CHAT_MESSAGE_LENGTH} characters)`,
        'VALIDATION_ERROR',
      ),
    );
  }

  return next();
}

function validateFeedback(req, res, next) {
  const { feedback, correctedAnswer } = req.body || {};

  if (feedback !== undefined && !['helpful', 'not_helpful', 'incorrect'].includes(feedback)) {
    return next(
      ApiError.badRequest(
        'feedback must be one of: helpful, not_helpful, incorrect',
        'VALIDATION_ERROR',
      ),
    );
  }

  if (correctedAnswer !== undefined && typeof correctedAnswer !== 'string') {
    return next(ApiError.badRequest('correctedAnswer must be a string', 'VALIDATION_ERROR'));
  }

  if (feedback === undefined && correctedAnswer === undefined) {
    return next(
      ApiError.badRequest('Provide feedback and/or correctedAnswer', 'VALIDATION_ERROR'),
    );
  }

  return next();
}

module.exports = {
  validateScanInvoice,
  validateChat,
  validateFeedback,
};

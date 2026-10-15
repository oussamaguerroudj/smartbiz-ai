const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const paymentsService = require('./payments.service');

const checkout = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const userId = req.user.id;
  const { successUrl, failureUrl } = req.body || {};

  const result = await paymentsService.createChargilyCheckout({
    companyId,
    userId,
    successUrl,
    failureUrl,
  });

  return res.json({ data: result });
});

const webhookChargily = asyncHandler(async (req, res) => {
  const signatureHeader = req.headers['signature'] || req.headers['Signature'];
  const rawBody = req.rawBody;
  const eventData = req.body;

  const result = await paymentsService.processChargilyWebhook({
    rawBody,
    signatureHeader,
    eventData,
  });

  return res.json({ success: true, data: result });
});

const createManualRequest = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const userId = req.user.id;
  const { transferReference } = req.body || {};

  const result = await paymentsService.createManualPaymentRequest({
    companyId,
    userId,
    transferReference,
  });

  return res.json({ data: result });
});

const uploadReceipt = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const companyId = req.user.companyId;
  const userId = req.user.id;
  const { fileBase64, filename, mimeType } = req.body || {};

  if (!fileBase64 || typeof fileBase64 !== 'string') {
    throw ApiError.badRequest('fileBase64 is required', 'VALIDATION_ERROR');
  }

  // Remove data URI prefix if present (e.g. data:image/png;base64,...)
  const cleanBase64 = fileBase64.replace(/^data:[^;]+;base64,/, '');
  const buffer = Buffer.from(cleanBase64, 'base64');

  const result = await paymentsService.uploadReceipt({
    requestId: id,
    companyId,
    userId,
    fileBuffer: buffer,
    originalFilename: filename || 'receipt.jpg',
    mimeType: mimeType || 'image/jpeg',
  });

  return res.json({ data: result });
});

const listManualRequests = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const requests = await paymentsService.getCompanyManualRequests(companyId);
  return res.json({ data: requests });
});

const viewReceipt = asyncHandler(async (req, res) => {
  const { filename } = req.params;
  const { filePath, fileBuffer, mimeType, originalFilename } = await paymentsService.getReceiptFile(
    filename,
    req.user,
  );

  res.setHeader('Content-Type', mimeType);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Security-Policy', "default-src 'none'");
  res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(originalFilename)}"`);
  if (fileBuffer) {
    return res.send(fileBuffer);
  }
  return res.sendFile(filePath);
});

const getOrderStatus = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const { orderId } = req.params;
  const order = await paymentsService.getPaymentOrderStatus(companyId, orderId);
  return res.json({ data: order });
});

const getActiveOrder = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const order = await paymentsService.getActivePaymentOrder(companyId);
  return res.json({ data: order });
});

module.exports = {
  checkout,
  webhookChargily,
  createManualRequest,
  uploadReceipt,
  listManualRequests,
  viewReceipt,
  getOrderStatus,
  getActiveOrder,
};

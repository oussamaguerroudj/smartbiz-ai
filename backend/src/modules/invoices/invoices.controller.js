const asyncHandler = require('../../utils/asyncHandler');
const service = require('./invoices.service');

const list = asyncHandler(async (req, res) => {
  res.json({ data: await service.list(req.user.companyId) });
});

const getOne = asyncHandler(async (req, res) => {
  res.json({ data: await service.getOne(req.user.companyId, req.params.id) });
});

const markPaid = asyncHandler(async (req, res) => {
  res.json({ data: await service.markPaid(req.user.companyId, req.params.id) });
});

const streamPdf = asyncHandler(async (req, res) => {
  await service.streamInvoicePdf(res, req.user.companyId, req.params.id);
});

const emailInvoice = asyncHandler(async (req, res) => {
  const { email } = req.body || {};
  const result = await service.emailInvoice(req.user.companyId, req.params.id, email);
  res.json({ data: result });
});

module.exports = { list, getOne, markPaid, pdfPlaceholder: streamPdf, streamPdf, emailInvoice };

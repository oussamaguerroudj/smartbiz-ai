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

// NOTE: real PDF generation (Ch. 14.1) needs a PDF library (e.g.
// pdfkit) + QR code generation — deliberately deferred to a dedicated
// batch since it's a distinct, non-trivial concern from CRUD wiring.
const pdfPlaceholder = asyncHandler(async (req, res) => {
  await service.getOne(req.user.companyId, req.params.id); // still validates ownership
  res.status(501).json({
    error: true,
    message: 'PDF export not implemented yet — planned as its own batch',
    code: 'NOT_IMPLEMENTED',
  });
});

module.exports = { list, getOne, markPaid, pdfPlaceholder };

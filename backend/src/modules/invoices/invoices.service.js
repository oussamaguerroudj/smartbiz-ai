const repo = require('./invoices.repository');
const ApiError = require('../../utils/ApiError');
const pdfService = require('../../utils/pdf.service');
const { query } = require('../../config/db');

async function list(companyId) {
  return repo.findAll(companyId);
}

async function getOne(companyId, id) {
  const invoice = await repo.findById(companyId, id);
  if (!invoice) throw ApiError.notFound('Invoice not found');
  return invoice;
}

async function markPaid(companyId, id) {
  const updated = await repo.updateStatus(companyId, id, 'paid');
  if (!updated) throw ApiError.notFound('Invoice not found');
  return updated;
}

async function streamInvoicePdf(res, companyId, id) {
  const [companyRes, invoice] = await Promise.all([
    query('SELECT name, phone, address FROM companies WHERE id = $1', [companyId]),
    getOne(companyId, id),
  ]);
  const company = companyRes.rows[0] || {};
  pdfService.streamStandardInvoicePdf(res, { company, invoice });
}

module.exports = { list, getOne, markPaid, streamInvoicePdf };

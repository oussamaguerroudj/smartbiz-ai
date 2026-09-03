const repo = require('./invoices.repository');
const ApiError = require('../../utils/ApiError');

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

module.exports = { list, getOne, markPaid };

const repo = require('./appointments.repository');
const ApiError = require('../../utils/ApiError');

async function list(companyId) {
  return repo.findAll(companyId);
}

async function createAppointment(companyId, data) {
  if (!data.scheduledAt) {
    throw ApiError.badRequest('scheduledAt is required', 'VALIDATION_ERROR');
  }
  return repo.create(companyId, data);
}

async function updateStatus(companyId, id, status) {
  if (!['scheduled', 'completed', 'cancelled', 'no_show'].includes(status)) {
    throw ApiError.badRequest('Invalid status', 'VALIDATION_ERROR');
  }
  const updated = await repo.updateStatus(companyId, id, status);
  if (!updated) throw ApiError.notFound('Appointment not found');
  return updated;
}

module.exports = { list, createAppointment, updateStatus };

const repo = require('./appointments.repository');
const ApiError = require('../../utils/ApiError');

const VALID_STATUSES = [
  'scheduled',
  'completed',
  'cancelled',
  'no_show',
];

function validateScheduledAt(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw ApiError.badRequest(
      'scheduledAt is required',
      'VALIDATION_ERROR',
    );
  }

  const timestamp = Date.parse(value);

  if (!Number.isFinite(timestamp)) {
    throw ApiError.badRequest(
      'scheduledAt must be a valid date/time',
      'VALIDATION_ERROR',
    );
  }
}

async function list(companyId) {
  return repo.findAll(companyId);
}

async function createAppointment(companyId, data = {}) {
  validateScheduledAt(data.scheduledAt);

  return repo.create(companyId, {
    ...data,
    scheduledAt: data.scheduledAt.trim(),
  });
}

async function updateStatus(companyId, id, status) {
  if (
    typeof status !== 'string' ||
    !VALID_STATUSES.includes(status)
  ) {
    throw ApiError.badRequest(
      `status must be one of: ${VALID_STATUSES.join(', ')}`,
      'VALIDATION_ERROR',
    );
  }

  const updated = await repo.updateStatus(
    companyId,
    id,
    status,
  );

  if (!updated) {
    throw ApiError.notFound('Appointment not found');
  }

  return updated;
}

module.exports = {
  list,
  createAppointment,
  updateStatus,
};
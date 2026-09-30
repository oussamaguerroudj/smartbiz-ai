const ApiError = require('../../utils/ApiError');

const PROJECT_STATUSES = ['planned', 'active', 'on_hold', 'completed', 'cancelled'];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function isValidDate(v) {
  return typeof v === 'string' && DATE_RE.test(v) && !Number.isNaN(new Date(v).getTime());
}

function validateCreateProject(req, res, next) {
  const { name, budget, status, startDate, dueDate, customerId } = req.body || {};
  const fail = (msg) => next(ApiError.badRequest(msg, 'VALIDATION_ERROR'));

  if (typeof name !== 'string' || name.trim().length === 0 || name.trim().length > 150) {
    return fail('name is required (max 150 characters)');
  }
  if (budget != null && (typeof budget !== 'number' || Number.isNaN(budget) || budget < 0)) {
    return fail('budget must be a non-negative number');
  }
  if (status != null && !PROJECT_STATUSES.includes(status)) {
    return fail(`status must be one of: ${PROJECT_STATUSES.join(', ')}`);
  }
  if (startDate != null && !isValidDate(startDate)) return fail('startDate must be YYYY-MM-DD');
  if (dueDate != null && !isValidDate(dueDate)) return fail('dueDate must be YYYY-MM-DD');
  if (startDate && dueDate && dueDate < startDate) return fail('dueDate cannot be before startDate');
  if (customerId != null && typeof customerId !== 'string') return fail('customerId must be a string');

  req.body.name = name.trim();
  return next();
}

function validateProjectStatus(req, res, next) {
  const { status } = req.body || {};
  if (!PROJECT_STATUSES.includes(status)) {
    return next(ApiError.badRequest(`status must be one of: ${PROJECT_STATUSES.join(', ')}`, 'VALIDATION_ERROR'));
  }
  return next();
}

module.exports = { validateCreateProject, validateProjectStatus, PROJECT_STATUSES };

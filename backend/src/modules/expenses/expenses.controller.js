const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const service = require('./expenses.service');

function isSalaryExpensePayload(body = {}) {
  return Boolean(
    body.employeeId ||
      body.salaryPeriod ||
      (typeof body.category === 'string' && body.category.trim().toLowerCase() === 'salary'),
  );
}

const list = asyncHandler(async (req, res) => {
  const { expenses, thisMonthTotal } = await service.list(req.user.companyId);
  res.json({ data: expenses, thisMonthTotal });
});

const create = asyncHandler(async (req, res) => {
  if (isSalaryExpensePayload(req.body) && req.user.role !== 'owner') {
    throw ApiError.forbidden('Only business owners can create salary expenses');
  }
  const expense = await service.createExpense(req.user.companyId, req.body);
  res.status(201).json({ data: expense });
});

const update = asyncHandler(async (req, res) => {
  if (isSalaryExpensePayload(req.body) && req.user.role !== 'owner') {
    throw ApiError.forbidden('Only business owners can modify salary expenses');
  }
  const expense = await service.updateExpense(req.user.companyId, req.params.id, req.body);
  res.json({ data: expense });
});

const remove = asyncHandler(async (req, res) => {
  res.json({ data: await service.deleteExpense(req.user.companyId, req.params.id) });
});

module.exports = { list, create, update, remove };

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./expenses.service');

const list = asyncHandler(async (req, res) => {
  const { expenses, thisMonthTotal } = await service.list(req.user.companyId);
  res.json({ data: expenses, thisMonthTotal });
});

const create = asyncHandler(async (req, res) => {
  const expense = await service.createExpense(req.user.companyId, req.body);
  res.status(201).json({ data: expense });
});

const remove = asyncHandler(async (req, res) => {
  res.json({ data: await service.deleteExpense(req.user.companyId, req.params.id) });
});

module.exports = { list, create, remove };

const repo = require('./expenses.repository');
const ApiError = require('../../utils/ApiError');

async function list(companyId) {
  const [expenses, thisMonthTotal] = await Promise.all([
    repo.findAll(companyId),
    repo.monthTotal(companyId),
  ]);
  return { expenses, thisMonthTotal };
}

async function createExpense(companyId, data) {
  if (!data.category || typeof data.amount !== 'number' || data.amount < 0) {
    throw ApiError.badRequest('category and a non-negative numeric amount are required', 'VALIDATION_ERROR');
  }
  return repo.create(companyId, data);
}

async function deleteExpense(companyId, id) {
  const deleted = await repo.softDelete(companyId, id);
  if (!deleted) throw ApiError.notFound('Expense not found');
  return { id };
}

module.exports = { list, createExpense, deleteExpense };

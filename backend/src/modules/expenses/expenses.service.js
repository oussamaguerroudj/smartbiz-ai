const repo = require('./expenses.repository');
const ApiError = require('../../utils/ApiError');

async function list(companyId) {
  const [expenses, thisMonthTotal] = await Promise.all([
    repo.findAll(companyId),
    repo.monthTotal(companyId),
  ]);

  return {
    expenses,
    thisMonthTotal,
  };
}

async function createExpense(companyId, data = {}) {
  const { category, amount } = data;

  if (
    typeof category !== 'string' ||
    category.trim().length === 0
  ) {
    throw ApiError.badRequest(
      'category is required',
      'VALIDATION_ERROR',
    );
  }

  if (
    typeof amount !== 'number' ||
    !Number.isFinite(amount) ||
    amount < 0
  ) {
    throw ApiError.badRequest(
      'amount must be a non-negative finite number',
      'VALIDATION_ERROR',
    );
  }

  return repo.create(companyId, {
    ...data,
    category: category.trim(),
  });
}

async function deleteExpense(companyId, id) {
  const deleted = await repo.softDelete(companyId, id);

  if (!deleted) {
    throw ApiError.notFound('Expense not found');
  }

  return {
    id,
  };
}

module.exports = {
  list,
  createExpense,
  deleteExpense,
};
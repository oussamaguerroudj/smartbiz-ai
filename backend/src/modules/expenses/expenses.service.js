const repo = require('./expenses.repository');
const ApiError = require('../../utils/ApiError');

const VALID_PERIOD_TYPES = ['one_time', 'daily', 'monthly', 'yearly', 'custom'];

function toDateOnly(value) {
  // Accepts a Date or an ISO-ish string; returns 'YYYY-MM-DD' or null.
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

function resolvePeriodEnd(periodType, periodStart) {
  switch (periodType) {
    case 'one_time':
    case 'daily':
      return periodStart;
    case 'monthly': {
      const start = new Date(`${periodStart}T00:00:00.000Z`);
      const nextMonth = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1));
      nextMonth.setUTCDate(nextMonth.getUTCDate() - 1);
      return nextMonth.toISOString().slice(0, 10);
    }
    case 'yearly': {
      const start = new Date(`${periodStart}T00:00:00.000Z`);
      const nextYear = new Date(Date.UTC(start.getUTCFullYear() + 1, start.getUTCMonth(), start.getUTCDate()));
      nextYear.setUTCDate(nextYear.getUTCDate() - 1);
      return nextYear.toISOString().slice(0, 10);
    }
    default:
      return null; // 'custom' — caller supplies period_end explicitly
  }
}

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
  const { category, amount, periodType, employeeId, salaryPeriod, duration, confirmedDuplicate } = data;

  if (typeof category !== 'string' || category.trim().length === 0) {
    throw ApiError.badRequest('category is required', 'VALIDATION_ERROR');
  }

  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount < 0) {
    throw ApiError.badRequest(
      'amount must be a non-negative finite number',
      'VALIDATION_ERROR',
    );
  }

  // Prevent accidental duplicate salary transactions unless explicitly confirmed
  if (employeeId && salaryPeriod) {
    const existing = await repo.checkDuplicateSalary(companyId, employeeId, salaryPeriod);
    if (existing && !confirmedDuplicate) {
      const err = ApiError.conflict(
        'A salary payment for this employee for this period already exists',
        'DUPLICATE_SALARY_PAYMENT',
      );
      err.details = {
        existingId: existing.id,
        amount: existing.amount,
        date: existing.expense_date,
        salaryPeriod: existing.salary_period,
      };
      throw err;
    }
  }

  const resolvedPeriodType = VALID_PERIOD_TYPES.includes(periodType)
    ? periodType
    : 'one_time';

  const periodStart =
    toDateOnly(data.periodStart) || toDateOnly(data.expenseDate) || toDateOnly(new Date());

  let periodEnd;

  if (resolvedPeriodType === 'custom') {
    periodEnd = toDateOnly(data.periodEnd);

    if (!periodEnd) {
      throw ApiError.badRequest(
        'periodEnd is required when periodType is custom',
        'VALIDATION_ERROR',
      );
    }

    if (periodEnd < periodStart) {
      throw ApiError.badRequest(
        'periodEnd cannot be before periodStart',
        'VALIDATION_ERROR',
      );
    }
  } else {
    periodEnd = resolvePeriodEnd(resolvedPeriodType, periodStart);
  }

  return repo.create(companyId, {
    category: category.trim(),
    description: data.description,
    amount,
    expenseDate: toDateOnly(data.expenseDate) || periodStart,
    periodType: resolvedPeriodType,
    periodStart,
    periodEnd,
    employeeId: employeeId || null,
    salaryPeriod: salaryPeriod || null,
    duration: duration || null,
  });
}

async function updateExpense(companyId, id, data = {}) {
  const existing = await repo.findById(companyId, id);
  if (!existing) {
    throw ApiError.notFound('Expense not found');
  }

  const category = data.category !== undefined ? data.category.trim() : existing.category;
  if (!category || category.length === 0) {
    throw ApiError.badRequest('category cannot be empty', 'VALIDATION_ERROR');
  }

  let amount = Number(existing.amount);
  if (data.amount !== undefined) {
    amount = Number(data.amount);
    if (!Number.isFinite(amount) || amount < 0) {
      throw ApiError.badRequest('amount must be a non-negative finite number', 'VALIDATION_ERROR');
    }
  }

  const employeeId = data.employeeId !== undefined ? data.employeeId : existing.employee_id;
  const salaryPeriod = data.salaryPeriod !== undefined ? data.salaryPeriod : existing.salary_period;
  const duration = data.duration !== undefined ? data.duration : existing.duration;

  if (employeeId && salaryPeriod && !data.confirmedDuplicate) {
    const dup = await repo.checkDuplicateSalary(companyId, employeeId, salaryPeriod, id);
    if (dup) {
      const err = ApiError.conflict(
        'A salary payment for this employee for this period already exists',
        'DUPLICATE_SALARY_PAYMENT',
      );
      err.details = {
        existingId: dup.id,
        amount: dup.amount,
        date: dup.expense_date,
        salaryPeriod: dup.salary_period,
      };
      throw err;
    }
  }

  const periodType = data.periodType !== undefined ? data.periodType : existing.period_type;
  const resolvedPeriodType = VALID_PERIOD_TYPES.includes(periodType) ? periodType : 'one_time';

  const expenseDate = data.expenseDate !== undefined ? toDateOnly(data.expenseDate) : toDateOnly(existing.expense_date);
  const periodStart = data.periodStart !== undefined ? toDateOnly(data.periodStart) : (toDateOnly(existing.period_start) || expenseDate);

  let periodEnd;
  if (resolvedPeriodType === 'custom') {
    periodEnd = data.periodEnd !== undefined ? toDateOnly(data.periodEnd) : toDateOnly(existing.period_end);
    if (!periodEnd) {
      throw ApiError.badRequest('periodEnd is required when periodType is custom', 'VALIDATION_ERROR');
    }
    if (periodEnd < periodStart) {
      throw ApiError.badRequest('periodEnd cannot be before periodStart', 'VALIDATION_ERROR');
    }
  } else {
    periodEnd = resolvePeriodEnd(resolvedPeriodType, periodStart);
  }

  const updated = await repo.update(companyId, id, {
    category,
    description: data.description !== undefined ? data.description : existing.description,
    amount,
    expenseDate,
    periodType: resolvedPeriodType,
    periodStart,
    periodEnd,
    employeeId,
    salaryPeriod,
    duration,
  });

  return updated;
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
  updateExpense,
  deleteExpense,
  resolvePeriodEnd,
};

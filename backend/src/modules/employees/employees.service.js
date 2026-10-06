const repo = require('./employees.repository');
const expensesService = require('../expenses/expenses.service');
const ApiError = require('../../utils/ApiError');

function currentPeriodMonth() {
  const now = new Date();

  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
}

function currentLocalDate() {
  const now = new Date();

  return [
    now.getFullYear(),
    String(now.getMonth() + 1).padStart(2, '0'),
    String(now.getDate()).padStart(2, '0'),
  ].join('-');
}

function validateFiniteNonNegativeNumber(value, fieldName) {
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    value < 0
  ) {
    throw ApiError.badRequest(
      `${fieldName} must be a non-negative finite number`,
      'VALIDATION_ERROR',
    );
  }
}

async function list(companyId) {
  return repo.findAll(companyId);
}

async function getOne(companyId, id) {
  const employee = await repo.findById(companyId, id);

  if (!employee) {
    throw ApiError.notFound('Employee not found');
  }

  const [attendance, salary, salaryPayments] = await Promise.all([
    repo.attendanceSummary(companyId, id),
    repo.netSalary(companyId, id, currentPeriodMonth()),
    repo.findSalaryPayments(companyId, id),
  ]);

  return {
    ...employee,
    attendance,
    salary,
    salaryPayments,
  };
}


async function createEmployee(companyId, data = {}) {
  const { name, baseSalary } = data;

  if (
    typeof name !== 'string' ||
    name.trim().length < 2
  ) {
    throw ApiError.badRequest(
      'name must be at least 2 characters',
      'VALIDATION_ERROR',
    );
  }

  validateFiniteNonNegativeNumber(
    baseSalary,
    'baseSalary',
  );

  return repo.create(companyId, {
    ...data,
    name: name.trim(),
  });
}

async function updateEmployee(companyId, id, data = {}) {
  const { name, baseSalary, position, phone } = data;

  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length < 2) {
      throw ApiError.badRequest('name must be at least 2 characters', 'VALIDATION_ERROR');
    }
  }

  if (baseSalary !== undefined) {
    validateFiniteNonNegativeNumber(baseSalary, 'baseSalary');
  }

  const updated = await repo.update(companyId, id, {
    name: typeof name === 'string' ? name.trim() : undefined,
    position: typeof position === 'string' ? position.trim() : position,
    phone: typeof phone === 'string' ? phone.trim() : phone,
    baseSalary: baseSalary !== undefined ? baseSalary : undefined,
  });

  if (!updated) {
    throw ApiError.notFound('Employee not found');
  }

  return updated;
}

async function deleteEmployee(companyId, id) {
  const deleted = await repo.softDelete(companyId, id);
  if (!deleted) {
    throw ApiError.notFound('Employee not found');
  }
  return { id };
}

async function markAttendance(
  companyId,
  employeeId,
  status,
) {
  if (!['present', 'absent', 'late'].includes(status)) {
    throw ApiError.badRequest(
      'status must be present, absent, or late',
      'VALIDATION_ERROR',
    );
  }

  const employee = await repo.findById(
    companyId,
    employeeId,
  );

  if (!employee) {
    throw ApiError.notFound('Employee not found');
  }

  const today = currentLocalDate();

  return repo.markAttendance(
    companyId,
    employeeId,
    today,
    status,
  );
}

async function addSalaryAdjustment(
  companyId,
  employeeId,
  data = {},
) {
  const {
    type,
    amount,
    note,
  } = data;

  if (!['bonus', 'deduction'].includes(type)) {
    throw ApiError.badRequest(
      'type must be bonus or deduction',
      'VALIDATION_ERROR',
    );
  }

  validateFiniteNonNegativeNumber(amount, 'amount');

  if (
    note !== undefined &&
    note !== null &&
    (
      typeof note !== 'string' ||
      note.trim().length > 1000
    )
  ) {
    throw ApiError.badRequest(
      'note must be a string with at most 1000 characters',
      'VALIDATION_ERROR',
    );
  }

  const employee = await repo.findById(
    companyId,
    employeeId,
  );

  if (!employee) {
    throw ApiError.notFound('Employee not found');
  }

  return repo.addSalaryAdjustment(
    companyId,
    employeeId,
    {
      type,
      amount,
      periodMonth: currentPeriodMonth(),
      note: typeof note === 'string'
        ? note.trim()
        : note,
    },
  );
}

async function paySalary(companyId, employeeId, data = {}) {
  const employee = await repo.findById(companyId, employeeId);
  if (!employee) {
    throw ApiError.notFound('Employee not found');
  }

  const amount = data.amount !== undefined ? Number(data.amount) : Number(employee.base_salary);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw ApiError.badRequest('Amount must be a positive number', 'VALIDATION_ERROR');
  }

  const paymentDate = data.paymentDate || currentLocalDate();
  const salaryPeriod = data.salaryPeriod || currentPeriodMonth().slice(0, 7); // e.g. '2026-09'
  const duration = data.duration || '1 month';
  const description = (data.description && data.description.trim().length > 0)
    ? data.description.trim()
    : `${employee.name} - ${salaryPeriod} salary`;

  // Creates an actual expense transaction stored in the expenses table
  return expensesService.createExpense(companyId, {
    category: 'Salary',
    amount,
    expenseDate: paymentDate,
    description,
    employeeId,
    salaryPeriod,
    duration,
    confirmedDuplicate: Boolean(data.confirmedDuplicate),
  });
}

async function getSalaryPayments(companyId, employeeId) {
  const employee = await repo.findById(companyId, employeeId);
  if (!employee) {
    throw ApiError.notFound('Employee not found');
  }
  return repo.findSalaryPayments(companyId, employeeId);
}

module.exports = {
  list,
  getOne,
  createEmployee,
  updateEmployee,
  deleteEmployee,
  markAttendance,
  addSalaryAdjustment,
  paySalary,
  getSalaryPayments,
};
const repo = require('./employees.repository');
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

  const attendance = await repo.attendanceSummary(
    companyId,
    id,
  );

  const salary = await repo.netSalary(
    companyId,
    id,
    currentPeriodMonth(),
  );

  return {
    ...employee,
    attendance,
    salary,
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

module.exports = {
  list,
  getOne,
  createEmployee,
  markAttendance,
  addSalaryAdjustment,
};
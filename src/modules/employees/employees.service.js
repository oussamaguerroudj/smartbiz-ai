const repo = require('./employees.repository');
const ApiError = require('../../utils/ApiError');

function currentPeriodMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
}

async function list(companyId) {
  return repo.findAll(companyId);
}

async function getOne(companyId, id) {
  const employee = await repo.findById(companyId, id);
  if (!employee) throw ApiError.notFound('Employee not found');
  const attendance = await repo.attendanceSummary(companyId, id);
  const salary = await repo.netSalary(companyId, id, currentPeriodMonth());
  return { ...employee, attendance, salary };
}

async function createEmployee(companyId, data) {
  if (!data.name || typeof data.baseSalary !== 'number' || data.baseSalary < 0) {
    throw ApiError.badRequest('name and a non-negative numeric baseSalary are required', 'VALIDATION_ERROR');
  }
  return repo.create(companyId, data);
}

async function markAttendance(companyId, employeeId, status) {
  if (!['present', 'absent', 'late'].includes(status)) {
    throw ApiError.badRequest('status must be present, absent, or late', 'VALIDATION_ERROR');
  }
  const employee = await repo.findById(companyId, employeeId);
  if (!employee) throw ApiError.notFound('Employee not found');
  const today = new Date().toISOString().slice(0, 10);
  return repo.markAttendance(companyId, employeeId, today, status);
}

async function addSalaryAdjustment(companyId, employeeId, { type, amount, note }) {
  if (!['bonus', 'deduction'].includes(type)) {
    throw ApiError.badRequest('type must be bonus or deduction', 'VALIDATION_ERROR');
  }
  if (typeof amount !== 'number' || amount < 0) {
    throw ApiError.badRequest('amount must be a non-negative number', 'VALIDATION_ERROR');
  }
  const employee = await repo.findById(companyId, employeeId);
  if (!employee) throw ApiError.notFound('Employee not found');
  return repo.addSalaryAdjustment(companyId, employeeId, {
    type,
    amount,
    periodMonth: currentPeriodMonth(),
    note,
  });
}

module.exports = { list, getOne, createEmployee, markAttendance, addSalaryAdjustment };

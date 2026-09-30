const asyncHandler = require('../../utils/asyncHandler');
const service = require('./employees.service');

const list = asyncHandler(async (req, res) => {
  res.json({ data: await service.list(req.user.companyId) });
});

const getOne = asyncHandler(async (req, res) => {
  res.json({ data: await service.getOne(req.user.companyId, req.params.id) });
});

const create = asyncHandler(async (req, res) => {
  const employee = await service.createEmployee(req.user.companyId, req.body);
  res.status(201).json({ data: employee });
});

const markAttendance = asyncHandler(async (req, res) => {
  const record = await service.markAttendance(req.user.companyId, req.params.id, req.body.status);
  res.status(201).json({ data: record });
});

const update = asyncHandler(async (req, res) => {
  const employee = await service.updateEmployee(req.user.companyId, req.params.id, req.body);
  res.json({ data: employee });
});

const remove = asyncHandler(async (req, res) => {
  res.json({ data: await service.deleteEmployee(req.user.companyId, req.params.id) });
});

const addSalaryAdjustment = asyncHandler(async (req, res) => {
  const adjustment = await service.addSalaryAdjustment(req.user.companyId, req.params.id, req.body);
  res.status(201).json({ data: adjustment });
});

const paySalary = asyncHandler(async (req, res) => {
  const payment = await service.paySalary(req.user.companyId, req.params.id, req.body);
  res.status(201).json({ data: payment });
});

const getSalaryPayments = asyncHandler(async (req, res) => {
  const payments = await service.getSalaryPayments(req.user.companyId, req.params.id);
  res.json({ data: payments });
});

module.exports = {
  list,
  getOne,
  create,
  update,
  remove,
  markAttendance,
  addSalaryAdjustment,
  paySalary,
  getSalaryPayments,
};


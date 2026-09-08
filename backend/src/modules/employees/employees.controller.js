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

const addSalaryAdjustment = asyncHandler(async (req, res) => {
  const adjustment = await service.addSalaryAdjustment(req.user.companyId, req.params.id, req.body);
  res.status(201).json({ data: adjustment });
});

module.exports = { list, getOne, create, markAttendance, addSalaryAdjustment };

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./sales.service');

const list = asyncHandler(async (req, res) => {
  const sales = await service.list(req.user.companyId);
  res.json({ data: sales });
});

const getOne = asyncHandler(async (req, res) => {
  const sale = await service.getOne(req.user.companyId, req.params.id);
  res.json({ data: sale });
});

const create = asyncHandler(async (req, res) => {
  const result = await service.createSale(req.user.companyId, {
    ...req.body,
    employeeId: req.body.employeeId,
  });
  res.status(201).json({ data: result });
});

module.exports = { list, getOne, create };

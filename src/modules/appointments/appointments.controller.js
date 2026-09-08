const asyncHandler = require('../../utils/asyncHandler');
const service = require('./appointments.service');

const list = asyncHandler(async (req, res) => {
  res.json({ data: await service.list(req.user.companyId) });
});

const create = asyncHandler(async (req, res) => {
  const appointment = await service.createAppointment(req.user.companyId, req.body);
  res.status(201).json({ data: appointment });
});

const updateStatus = asyncHandler(async (req, res) => {
  const updated = await service.updateStatus(req.user.companyId, req.params.id, req.body.status);
  res.json({ data: updated });
});

module.exports = { list, create, updateStatus };

const asyncHandler = require('../../utils/asyncHandler');
const service = require('./superette.service');

const getDashboard = asyncHandler(async (req, res) => {
  res.json({ data: await service.getDashboard(req.user.companyId) });
});

module.exports = { getDashboard };

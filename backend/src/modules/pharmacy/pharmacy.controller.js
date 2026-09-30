const asyncHandler = require('../../utils/asyncHandler');
const service = require('./pharmacy.service');
const repo = require('./pharmacy.repository');

const getDashboard = asyncHandler(async (req, res) => {
  res.json({ data: await service.getDashboard(req.user.companyId) });
});

/** Full expiring-products list (the dashboard aggregate above only
 * returns a top-10 preview) — its own endpoint so a dedicated "Expiry
 * Alerts" screen can page through everything, per Ch. 15. */
const getExpiringProducts = asyncHandler(async (req, res) => {
  const days = Math.min(365, Math.max(1, Number(req.query.days) || 30));
  const products = await repo.expiringProducts(req.user.companyId, days, 200);
  res.json({ data: products });
});

module.exports = { getDashboard, getExpiringProducts };

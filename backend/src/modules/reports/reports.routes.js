const express = require('express');
const asyncHandler = require('../../utils/asyncHandler');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const { calculateFinancials } = require('../financial/financial.service');

/**
 * Reports  -  All figures are calculated via the central financial calculation
 * service (financial.service.js) guaranteeing identical calculation logic with
 * the Dashboard, zero double-counting, and strict date boundaries.
 */
const getReport = asyncHandler(async (req, res) => {
  const data = await calculateFinancials(req.user.companyId, req.query);
  return res.json({ data });
});

const router = express.Router();

router.use(authMiddleware);

router.get('/', getReport);

module.exports = router;

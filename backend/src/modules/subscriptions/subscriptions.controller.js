const crypto = require('crypto');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const subscriptionsService = require('./subscriptions.service');
const { processTrialReminders } = require('../notifications/reminders.service');

const getStatus = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const status = await subscriptionsService.getEntitlementStatus(companyId);
  return res.json({ data: status });
});

const startTrial = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const userId = req.user.id;
  const result = await subscriptionsService.selectFreeTrial(companyId, userId);
  return res.json({ data: result });
});

const getProduct = asyncHandler(async (req, res) => {
  const product = subscriptionsService.getLifetimeProduct();
  return res.json({ data: product });
});

/**
 * Scheduled Cron Trigger Endpoint
 * Authenticated via dedicated high-entropy secret (x-scheduler-secret or Bearer token).
 * Fails closed if secret is unconfigured.
 * Returns only aggregated metrics, never tenant data.
 */
const cronProcessReminders = asyncHandler(async (req, res) => {
  const configuredSecret = process.env.SCHEDULER_SECRET || process.env.CRON_SECRET;
  if (!configuredSecret || typeof configuredSecret !== 'string' || !configuredSecret.trim()) {
    throw ApiError.forbidden('Scheduler trigger is unconfigured on server', 'SCHEDULER_UNCONFIGURED');
  }

  const authHeader = req.headers['authorization'];
  const customHeader = req.headers['x-scheduler-secret'];
  const providedSecret =
    customHeader ||
    (authHeader && authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : null);

  if (!providedSecret || typeof providedSecret !== 'string') {
    throw ApiError.unauthorized('Missing scheduler authentication secret', 'MISSING_SCHEDULER_SECRET');
  }

  let isMatch = false;
  try {
    const expectedBuf = Buffer.from(configuredSecret.trim());
    const providedBuf = Buffer.from(providedSecret.trim());
    if (expectedBuf.length === providedBuf.length && crypto.timingSafeEqual(expectedBuf, providedBuf)) {
      isMatch = true;
    }
  } catch (_) {
    isMatch = false;
  }

  if (!isMatch) {
    throw ApiError.unauthorized('Invalid scheduler authentication secret', 'INVALID_SCHEDULER_SECRET');
  }

  const result = await processTrialReminders();

  return res.json({
    success: true,
    data: {
      ...result,
      timestamp: new Date().toISOString(),
    },
  });
});

module.exports = {
  getStatus,
  startTrial,
  getProduct,
  cronProcessReminders,
};

const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware } = require('../../middlewares/auth.middleware');

/**
 * Notifications
 *
 * Derived notifications are calculated from real company data:
 * - low_stock
 * - unpaid_invoice
 *
 * Stored notifications are user/company scoped and can later be
 * populated by scheduled jobs for reminders.
 */

async function deriveLowStock(companyId) {
  const result = await query(
    `SELECT id, name, quantity
     FROM products
     WHERE company_id = $1
       AND deleted_at IS NULL
       AND quantity <= minimum_stock
     ORDER BY quantity ASC`,
    [companyId],
  );

  return result.rows.map((product) => ({
    type: 'low_stock',
    title: product.quantity === 0
      ? `Out of stock: ${product.name}`
      : `Low stock: ${product.name}`,
    body: `${product.quantity} units remaining`,
    referenceId: product.id,
  }));
}

async function deriveUnpaidInvoices(companyId) {
  const result = await query(
    `SELECT id, invoice_number
     FROM invoices
     WHERE company_id = $1
       AND status = 'unpaid'
     ORDER BY created_at DESC`,
    [companyId],
  );

  return result.rows.map((invoice) => ({
    type: 'unpaid_invoice',
    title: `Invoice ${invoice.invoice_number} still unpaid`,
    body: 'Tap to view details',
    referenceId: invoice.id,
  }));
}

async function deriveExpiringSoon(companyId) {
  try {
    const result = await query(
      `SELECT id, name, quantity, expiration_date
       FROM products
       WHERE company_id = $1
         AND deleted_at IS NULL
         AND expiration_date IS NOT NULL
         AND expiration_date > CURRENT_DATE
         AND expiration_date <= CURRENT_DATE + INTERVAL '30 days'
         AND quantity > 0
       ORDER BY expiration_date ASC
       LIMIT 20`,
      [companyId],
    );

    return result.rows.map((product) => {
      const expDate = new Date(product.expiration_date).toISOString().substring(0, 10);
      return {
        type: 'expiring_soon',
        title: `Expiring soon: ${product.name}`,
        body: `Expires on ${expDate} (${product.quantity} in stock)`,
        referenceId: product.id,
      };
    });
  } catch (_) {
    return [];
  }
}

async function deriveExpiredStock(companyId) {
  try {
    const result = await query(
      `SELECT id, name, quantity, expiration_date
       FROM products
       WHERE company_id = $1
         AND deleted_at IS NULL
         AND expiration_date IS NOT NULL
         AND expiration_date <= CURRENT_DATE
         AND quantity > 0
       ORDER BY expiration_date ASC
       LIMIT 20`,
      [companyId],
    );

    return result.rows.map((product) => {
      const expDate = new Date(product.expiration_date).toISOString().substring(0, 10);
      return {
        type: 'expired_stock',
        title: `Expired product: ${product.name}`,
        body: `Expired on ${expDate} (${product.quantity} in stock)`,
        referenceId: product.id,
      };
    });
  } catch (_) {
    return [];
  }
}

async function deriveCustomerDebts(companyId) {
  try {
    const result = await query(
      `SELECT id, name, balance_due
       FROM customers
       WHERE company_id = $1
         AND deleted_at IS NULL
         AND balance_due > 0
       ORDER BY balance_due DESC
       LIMIT 20`,
      [companyId],
    );

    return result.rows.map((cust) => ({
      type: 'debt_reminder',
      title: `Debt reminder: ${cust.name}`,
      body: `${Number(cust.balance_due).toFixed(0)} DZD outstanding balance`,
      referenceId: cust.id,
    }));
  } catch (_) {
    return [];
  }
}

async function deriveTrialExpiring(companyId) {
  try {
    const result = await query(
      `SELECT id, entitlement_status, trial_ends_at
       FROM companies
       WHERE id = $1
         AND entitlement_status = 'trial'
         AND trial_ends_at IS NOT NULL
         AND trial_ends_at <= CURRENT_DATE + INTERVAL '3 days'
         AND trial_ends_at > CURRENT_DATE - INTERVAL '1 day'`,
      [companyId],
    );

    return result.rows.map((c) => ({
      type: 'trial_expiring',
      title: 'Trial period ending soon',
      body: `Your free trial expires on ${new Date(c.trial_ends_at).toISOString().substring(0, 10)}. Upgrade to lifetime license for 15,000 DZD.`,
      referenceId: c.id,
    }));
  } catch (_) {
    return [];
  }
}

async function storedNotifications(companyId, userId) {
  const result = await query(
    `SELECT *
     FROM notifications
     WHERE company_id = $1
       AND (user_id = $2 OR user_id IS NULL)
     ORDER BY created_at DESC
     LIMIT 50`,
    [companyId, userId],
  );

  return result.rows;
}

const list = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;
  const userId = req.user.id;

  const [
    lowStock,
    unpaidInvoices,
    expiringSoon,
    expiredStock,
    customerDebts,
    trialExpiring,
    stored,
  ] = await Promise.all([
    deriveLowStock(companyId),
    deriveUnpaidInvoices(companyId),
    deriveExpiringSoon(companyId),
    deriveExpiredStock(companyId),
    deriveCustomerDebts(companyId),
    deriveTrialExpiring(companyId),
    storedNotifications(companyId, userId),
  ]);

  return res.json({
    data: [
      ...lowStock,
      ...unpaidInvoices,
      ...expiringSoon,
      ...expiredStock,
      ...customerDebts,
      ...trialExpiring,
      ...stored,
    ],
  });
});

const markRead = asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (typeof id !== 'string' || id.trim().length === 0) {
    throw ApiError.badRequest(
      'Notification id is required',
      'VALIDATION_ERROR',
    );
  }

  const result = await query(
    `UPDATE notifications
     SET read_at = now()
     WHERE company_id = $1
       AND id = $2
       AND (user_id = $3 OR user_id IS NULL)
     RETURNING *`,
    [
      req.user.companyId,
      id,
      req.user.id,
    ],
  );

  if (!result.rows[0]) {
    throw ApiError.notFound('Notification not found');
  }

  return res.json({
    data: result.rows[0],
  });
});

const pushService = require('./push.service');

const registerToken = asyncHandler(async (req, res) => {
  const { token, platform, deviceInfo } = req.body;
  if (!token || typeof token !== 'string' || !token.trim()) {
    throw ApiError.badRequest('Push device token is required', 'VALIDATION_ERROR');
  }

  const result = await pushService.registerDeviceToken({
    userId: req.user.id,
    companyId: req.user.companyId,
    token: token.trim(),
    platform: platform || 'android',
    deviceInfo: deviceInfo || {},
  });

  return res.status(201).json({
    data: result,
    message: 'Device token registered successfully',
  });
});

const unregisterToken = asyncHandler(async (req, res) => {
  const { token } = req.body;
  if (!token || typeof token !== 'string' || !token.trim()) {
    throw ApiError.badRequest('Device token is required', 'VALIDATION_ERROR');
  }

  const result = await pushService.unregisterDeviceToken({
    userId: req.user.id,
    token: token.trim(),
  });

  return res.json({
    data: result,
    message: 'Device token unregistered successfully',
  });
});

const router = express.Router();

router.use(authMiddleware);

router.get('/', list);
router.put('/:id/read', markRead);
router.post('/device-token', registerToken);
router.delete('/device-token', unregisterToken);

module.exports = router;
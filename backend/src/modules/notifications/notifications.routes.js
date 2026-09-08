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
    stored,
  ] = await Promise.all([
    deriveLowStock(companyId),
    deriveUnpaidInvoices(companyId),
    storedNotifications(companyId, userId),
  ]);

  return res.json({
    data: [
      ...lowStock,
      ...unpaidInvoices,
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

const router = express.Router();

router.use(authMiddleware);

router.get('/', list);
router.put('/:id/read', markRead);

module.exports = router;
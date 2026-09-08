const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const { authMiddleware } = require('../../middlewares/auth.middleware');

/**
 * Notifications — Spec Ch. 19. Mirrors the same principle used on the
 * Flutter side (Phase 4): low_stock and unpaid_invoice notifications are
 * DERIVED live from real data rather than requiring a background job to
 * pre-populate the `notifications` table — so they're never stale and
 * never fabricated. appointment_reminder / salary_reminder DO need a
 * scheduler (a cron-like job writing rows into `notifications` ahead of
 * time) — that's a Phase 6/7 concern; the table and endpoint below are
 * ready to serve them once that job exists.
 */
async function deriveLowStock(companyId) {
  const result = await query(
    `SELECT id, name, quantity FROM products
     WHERE company_id = $1 AND deleted_at IS NULL AND quantity <= minimum_stock
     ORDER BY quantity ASC`,
    [companyId],
  );
  return result.rows.map((p) => ({
    type: 'low_stock',
    title: p.quantity === 0 ? `Out of stock: ${p.name}` : `Low stock: ${p.name}`,
    body: `${p.quantity} units remaining`,
    referenceId: p.id,
  }));
}

async function deriveUnpaidInvoices(companyId) {
  const result = await query(
    `SELECT id, invoice_number FROM invoices WHERE company_id = $1 AND status = 'unpaid'`,
    [companyId],
  );
  return result.rows.map((i) => ({
    type: 'unpaid_invoice',
    title: `Invoice ${i.invoice_number} still unpaid`,
    body: 'Tap to view details',
    referenceId: i.id,
  }));
}

async function storedNotifications(companyId, userId) {
  const result = await query(
    `SELECT * FROM notifications WHERE company_id = $1 AND (user_id = $2 OR user_id IS NULL)
     ORDER BY created_at DESC LIMIT 50`,
    [companyId, userId],
  );
  return result.rows;
}

const list = asyncHandler(async (req, res) => {
  const [lowStock, unpaidInvoices, stored] = await Promise.all([
    deriveLowStock(req.user.companyId),
    deriveUnpaidInvoices(req.user.companyId),
    storedNotifications(req.user.companyId, req.user.id),
  ]);
  res.json({ data: [...lowStock, ...unpaidInvoices, ...stored] });
});

const markRead = asyncHandler(async (req, res) => {
  const result = await query(
    `UPDATE notifications SET read_at = now() WHERE company_id = $1 AND id = $2 RETURNING *`,
    [req.user.companyId, req.params.id],
  );
  res.json({ data: result.rows[0] || null });
});

const router = express.Router();
router.use(authMiddleware);
router.get('/', list);
router.put('/:id/read', markRead);

module.exports = router;

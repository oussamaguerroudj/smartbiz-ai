const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const clinicRepo = require('../clinic/clinic.repository');
const restaurantRepo = require('../restaurant/restaurant.repository');
const { calculateFinancials } = require('../financial/financial.service');

/**
 * Dashboard — Spec Ch. 9.1.
 * Financial figures are powered directly by calculateFinancials (daily period),
 * guaranteeing a single source of truth between the Dashboard and Reports.
 */
const getDashboard = asyncHandler(async (req, res) => {
  const companyId = req.user.companyId;

  const [
    financials,
    clinicOutstanding,
    restaurantOutstanding,
    lowStock,
    unpaidInvoices,
    upcomingAppointments,
    outstandingCredit,
  ] = await Promise.all([
    calculateFinancials(companyId, { period: 'daily' }),
    clinicRepo.outstandingTotal(companyId),
    restaurantRepo.outstandingTotal(companyId),
    query(
      `SELECT COUNT(*)::int AS count FROM products
       WHERE company_id = $1 AND deleted_at IS NULL AND quantity <= minimum_stock`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM invoices WHERE company_id = $1 AND status = 'unpaid'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM appointments
       WHERE company_id = $1 AND status = 'scheduled' AND scheduled_at >= now()`,
      [companyId],
    ),
    query(
      `SELECT COALESCE(SUM(balance_due), 0) AS total FROM customers WHERE company_id = $1 AND deleted_at IS NULL`,
      [companyId],
    ).catch(() => ({ rows: [{ total: 0 }] })),
  ]);

  res.json({
    data: {
      todayRevenue: financials.revenue,
      todayExpenses: financials.expenses,
      todayOperatingExpenses: financials.operatingExpenses,
      todaySalaryCost: financials.employeeSalaries,
      todayCostOfGoodsSold: financials.costOfGoodsSold,
      todayGrossProfit: financials.grossProfit,
      todayProfit: financials.netProfit,
      salesCount: financials.salesCount,
      lowStockCount: lowStock.rows[0].count,
      unpaidInvoicesCount: unpaidInvoices.rows[0].count,
      upcomingAppointmentsCount: upcomingAppointments.rows[0].count,
      totalOutstandingCredit:
        Number(outstandingCredit.rows[0].total) + clinicOutstanding + restaurantOutstanding,
    },
  });
});

const router = express.Router();
router.use(authMiddleware);
router.get('/', getDashboard);

module.exports = router;

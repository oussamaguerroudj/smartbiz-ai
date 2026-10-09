const repo = require('./pharmacy.repository');
const expensesRepo = require('../expenses/expenses.repository');

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

/**
 * Ch. 15's dashboard, built entirely from CORE data plus the two
 * pharmacy-only reads (expiry, inventory value) — no separate
 * "pharmacy revenue" concept exists because pharmacy revenue IS
 * product-sale revenue (Ch. 21: "Pharmacy revenue = actual product
 * sales"), unlike Clinic where revenue explicitly is NOT a sales
 * concept at all.
 *
 * `todayNetProfit` follows the exact same formula as the CORE
 * dashboard (dashboard.routes.js) and Reports (reports.routes.js):
 * revenue - operating expenses, NOT revenue - COGS - expenses —
 * `todayGrossProfit` (cost-of-goods aware, from sale_items.line_profit)
 * is reported alongside it as its own field, matching how Reports
 * already separates `netProfit` from `grossProfit` rather than
 * inventing a third profit formula for this vertical.
 */
async function getDashboard(companyId) {
  const now = new Date();
  const todayStr = toDateStr(now);
  const weekStart = toDateStr(new Date(now.getTime() - 6 * 86400000));
  const monthStart = toDateStr(new Date(now.getFullYear(), now.getMonth(), 1));

  const [
    today,
    week,
    month,
    todayExpenses,
    lowStock,
    lowStockList,
    expiring,
    expiringList,
    expired,
    inventory,
    bestSellers,
    suppliersTotal,
  ] = await Promise.all([
    repo.salesSummaryForRange(companyId, todayStr, todayStr),
    repo.salesSummaryForRange(companyId, weekStart, todayStr),
    repo.salesSummaryForRange(companyId, monthStart, todayStr),
    expensesRepo.totalForRange(companyId, todayStr, todayStr),
    repo.lowStockCount(companyId),
    repo.lowStockProducts(companyId, 10),
    repo.expiringCount(companyId, 30),
    repo.expiringProducts(companyId, 30, 10),
    repo.expiredCount(companyId),
    repo.inventoryValue(companyId),
    repo.bestSellingProducts(companyId, weekStart, todayStr, 5),
    repo.suppliersCount(companyId),
  ]);

  return {
    todayRevenue: today.revenue,
    todayGrossProfit: today.grossProfit,
    todayNetProfit: today.grossProfit - todayExpenses,
    todayExpenses,
    transactionsToday: today.transactionCount,
    productsSoldToday: today.unitsSold,
    weekRevenue: week.revenue,
    monthRevenue: month.revenue,
    lowStockCount: lowStock,
    lowStockProducts: lowStockList,
    expiringCount: expiring,
    expiringProducts: expiringList,
    expiredCount: expired,
    inventoryCostValue: inventory.costValue,
    inventoryRetailValue: inventory.retailValue,
    unitsInStock: inventory.unitsInStock,
    bestSellingProducts: bestSellers,
    suppliersCount: suppliersTotal,
  };
}

module.exports = { getDashboard };

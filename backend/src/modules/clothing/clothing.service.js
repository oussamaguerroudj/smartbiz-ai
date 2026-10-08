const repo = require('./clothing.repository');
const expensesRepo = require('../expenses/expenses.repository');

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

/**
 * Ch. 18's dashboard, built entirely from CORE data (products, sales,
 * suppliers, customers, expenses) plus the Ch. 18-specific attribute
 * columns added by migration 020  -  clothing revenue IS product-sale
 * revenue (Ch. 21), same as Pharmacy and Supérette.
 *
 * `todayNetProfit` follows the exact same formula as CORE/Reports/
 * Pharmacy/Supérette: revenue - operating expenses. `todayGrossProfit`
 * (COGS-aware, from sale_items.line_profit) is its own field.
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
    stock,
    bestSellers,
    categories,
    suppliersTotal,
    customersTotal,
    debt,
  ] = await Promise.all([
    repo.salesSummaryForRange(companyId, todayStr, todayStr),
    repo.salesSummaryForRange(companyId, weekStart, todayStr),
    repo.salesSummaryForRange(companyId, monthStart, todayStr),
    expensesRepo.totalForRange(companyId, todayStr, todayStr),
    repo.lowStockCount(companyId),
    repo.lowStockProducts(companyId, 10),
    repo.stockValue(companyId),
    repo.bestSellingProducts(companyId, weekStart, todayStr, 5),
    repo.stockByCategory(companyId, 8),
    repo.suppliersCount(companyId),
    repo.customersCount(companyId),
    repo.customerDebt(companyId, 5),
  ]);

  return {
    todayRevenue: today.revenue,
    todayGrossProfit: today.grossProfit,
    todayNetProfit: today.revenue - todayExpenses,
    todayExpenses,
    transactionsToday: today.transactionCount,
    itemsSoldToday: today.unitsSold,
    weekRevenue: week.revenue,
    monthRevenue: month.revenue,
    lowStockCount: lowStock,
    lowStockProducts: lowStockList,
    stockCostValue: stock.costValue,
    stockRetailValue: stock.retailValue,
    unitsInStock: stock.unitsInStock,
    bestSellingProducts: bestSellers,
    stockByCategory: categories,
    suppliersCount: suppliersTotal,
    customersCount: customersTotal,
    outstandingDebt: debt.totalOutstanding,
    debtorsCount: debt.debtorsCount,
    topDebtors: debt.topDebtors,
  };
}

module.exports = { getDashboard };

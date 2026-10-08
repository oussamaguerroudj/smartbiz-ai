const repo = require('./superette.repository');
const expensesRepo = require('../expenses/expenses.repository');

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

/**
 * Ch. 16's dashboard, built entirely from CORE data (products, sales,
 * suppliers, customers, expenses)  -  no separate "supérette revenue"
 * concept exists because, exactly like Pharmacy, supérette revenue IS
 * product-sale revenue (Ch. 21: "Retail revenue = actual product
 * sales").
 *
 * `todayNetProfit` follows the exact same formula as the CORE
 * dashboard and Reports: revenue - operating expenses.
 * `todayGrossProfit` (cost-of-goods aware, from sale_items.line_profit)
 * is reported alongside it as its own field, same split Pharmacy's
 * dashboard already makes.
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
    productsSoldToday: today.unitsSold,
    weekRevenue: week.revenue,
    monthRevenue: month.revenue,
    lowStockCount: lowStock,
    lowStockProducts: lowStockList,
    stockCostValue: stock.costValue,
    stockRetailValue: stock.retailValue,
    unitsInStock: stock.unitsInStock,
    bestSellingProducts: bestSellers,
    suppliersCount: suppliersTotal,
    customersCount: customersTotal,
    outstandingDebt: debt.totalOutstanding,
    debtorsCount: debt.debtorsCount,
    topDebtors: debt.topDebtors,
  };
}

module.exports = { getDashboard };

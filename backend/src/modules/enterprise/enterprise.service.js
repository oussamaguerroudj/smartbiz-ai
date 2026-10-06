const repo = require('./enterprise.repository');
const expensesRepo = require('../expenses/expenses.repository');
const employeesRepo = require('../employees/employees.repository');
const creditRepo = require('../credit/credit.repository');
const ApiError = require('../../utils/ApiError');

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

/**
 * Revenue / expenses / profit for one date range, using EXACTLY the
 * same building blocks as the CORE dashboard (`dashboard.routes.js`),
 * so an Enterprise account's numbers can never disagree with what the
 * CORE dashboard and Reports would show for the same period (Ch. 21's
 * single-source-of-truth rule):
 *
 *   revenue  = sales.total (invoiced sales) + credit payments received
 *   expenses = operating expenses (prorated) + employee salary cost
 *   profit   = revenue - expenses
 *
 * Ch. 19 lists Revenue / Expenses / Profit / Salaries as separate
 * items, so payroll is also returned on its own.
 */
async function financialsForRange(companyId, rangeStart, rangeEnd) {
  const [sales, creditPayments, operatingExpenses, payroll] = await Promise.all([
    repo.salesRevenueForRange(companyId, rangeStart, rangeEnd),
    creditRepo.totalPaymentsForRange(companyId, rangeStart, rangeEnd),
    expensesRepo.totalForRange(companyId, rangeStart, rangeEnd),
    employeesRepo.totalSalaryCostForRange(companyId, rangeStart, rangeEnd),
  ]);
  const revenue = sales.revenue + creditPayments;
  const expenses = operatingExpenses + payroll;
  return {
    revenue,
    invoicedRevenue: sales.revenue,
    creditPayments,
    invoicesIssued: sales.invoicesIssued,
    operatingExpenses,
    payroll,
    expenses,
    netProfit: revenue - expenses,
  };
}

async function getDashboard(companyId) {
  const now = new Date();
  const todayStr = toDateStr(now);
  const weekStart = toDateStr(new Date(now.getTime() - 6 * 86400000));
  const monthStart = toDateStr(new Date(now.getFullYear(), now.getMonth(), 1));

  const [today, week, month, invoices, balances, clients, employees, suppliers, projects, openProjects] =
    await Promise.all([
      financialsForRange(companyId, todayStr, todayStr),
      financialsForRange(companyId, weekStart, todayStr),
      financialsForRange(companyId, monthStart, todayStr),
      repo.unpaidInvoices(companyId, 5),
      repo.clientBalances(companyId),
      repo.clientsCount(companyId),
      repo.employeesCount(companyId),
      repo.suppliersCount(companyId),
      repo.projectSummary(companyId),
      repo.openProjects(companyId, 5),
    ]);

  return {
    todayRevenue: today.revenue,
    todayExpenses: today.expenses,
    todayNetProfit: today.netProfit,
    invoicesIssuedToday: today.invoicesIssued,
    weekRevenue: week.revenue,
    monthRevenue: month.revenue,
    monthExpenses: month.expenses,
    monthOperatingExpenses: month.operatingExpenses,
    monthPayroll: month.payroll,
    monthNetProfit: month.netProfit,
    unpaidInvoicesCount: invoices.count,
    unpaidInvoicesAmount: invoices.totalAmount,
    unpaidInvoices: invoices.list,
    clientBalancesOutstanding: balances.total,
    clientsWithBalance: balances.count,
    clientsCount: clients,
    employeesCount: employees,
    suppliersCount: suppliers,
    projects,
    openProjects,
  };
}

// ---------------------------------------------------------------------
// Projects
// ---------------------------------------------------------------------

async function listProjects(companyId, status) {
  return repo.listProjects(companyId, status);
}

async function createProject(companyId, data) {
  if (data.customerId) {
    // A project can only be linked to a client of THIS company.
    const ok = await repo.customerExists(companyId, data.customerId);
    if (!ok) throw ApiError.badRequest('customerId does not match any client', 'VALIDATION_ERROR');
  }
  return repo.createProject(companyId, data);
}

async function updateProjectStatus(companyId, id, status) {
  const updated = await repo.updateProjectStatus(companyId, id, status);
  if (!updated) throw ApiError.notFound('Project not found', 'PROJECT_NOT_FOUND');
  return updated;
}

module.exports = { getDashboard, financialsForRange, listProjects, createProject, updateProjectStatus };

const repo = require('../superette.repository');
const service = require('../superette.service');
const { query } = require('../../../config/db');
const expensesRepo = require('../../expenses/expenses.repository');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
}));

jest.mock('../../expenses/expenses.repository', () => ({
  totalForRange: jest.fn(),
}));

describe('Superette Financial & Sales Summary Calculations', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  const companyId = '00000000-0000-0000-0000-000000000001';

  it('salesSummaryForRange returns revenue as sales total, not line_profit', async () => {
    // Scenario: 1 sale of 400 DZD with cost 380 DZD. line_profit = 20 DZD.
    // revenue must be 400, gross_profit must be 20.
    query.mockResolvedValueOnce({
      rows: [
        {
          revenue: '400.00',
          gross_profit: '20.00',
          transaction_count: '1',
          units_sold: '1',
        },
      ],
    });

    const summary = await repo.salesSummaryForRange(companyId, '2026-10-09', '2026-10-09');

    expect(summary.revenue).toBe(400);
    expect(summary.grossProfit).toBe(20);
    expect(summary.transactionCount).toBe(1);
    expect(summary.unitsSold).toBe(1);

    // Verify the SQL sent to the database selects SUM(s2.total) for revenue
    const sql = query.mock.calls[0][0];
    expect(sql).toContain('SELECT SUM(s2.total)');
    expect(sql).toContain('AS revenue');
  });

  it('salesSummaryForRange handles empty rows gracefully', async () => {
    query.mockResolvedValueOnce({
      rows: [],
    });

    const summary = await repo.salesSummaryForRange(companyId, '2026-10-09', '2026-10-09');

    expect(summary.revenue).toBe(0);
    expect(summary.grossProfit).toBe(0);
    expect(summary.transactionCount).toBe(0);
    expect(summary.unitsSold).toBe(0);
  });

  it('getDashboard calculates todayNetProfit as grossProfit - todayExpenses', async () => {
    // Mock salesSummaryForRange for today, week, month
    jest.spyOn(repo, 'salesSummaryForRange').mockImplementation((_, start, end) => {
      return Promise.resolve({
        revenue: 400,
        grossProfit: 20,
        transactionCount: 1,
        unitsSold: 1,
      });
    });
    jest.spyOn(repo, 'lowStockCount').mockResolvedValue(0);
    jest.spyOn(repo, 'lowStockProducts').mockResolvedValue([]);
    jest.spyOn(repo, 'stockValue').mockResolvedValue({ costValue: 0, retailValue: 0, unitsInStock: 0 });
    jest.spyOn(repo, 'bestSellingProducts').mockResolvedValue([]);
    jest.spyOn(repo, 'suppliersCount').mockResolvedValue(0);
    jest.spyOn(repo, 'customersCount').mockResolvedValue(0);
    jest.spyOn(repo, 'customerDebt').mockResolvedValue({ totalOutstanding: 0, debtorsCount: 0, topDebtors: [] });

    // Operating expenses = 0
    expensesRepo.totalForRange.mockResolvedValue(0);

    const dashboard = await service.getDashboard(companyId);

    expect(dashboard.todayRevenue).toBe(400);
    expect(dashboard.todayGrossProfit).toBe(20);
    // Net profit = grossProfit (20) - expenses (0) = 20
    expect(dashboard.todayNetProfit).toBe(20);
    expect(dashboard.todayExpenses).toBe(0);
  });
});

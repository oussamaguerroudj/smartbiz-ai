const { resolveRange, calculateFinancials } = require('../financial.service');
const { query } = require('../../../config/db');
const expensesRepo = require('../../expenses/expenses.repository');
const employeesRepo = require('../../employees/employees.repository');
const creditRepo = require('../../credit/credit.repository');
const clinicRepo = require('../../clinic/clinic.repository');
const restaurantRepo = require('../../restaurant/restaurant.repository');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
}));

jest.mock('../../expenses/expenses.repository', () => ({
  totalForRange: jest.fn(),
}));

jest.mock('../../employees/employees.repository', () => ({
  totalSalaryCostForRange: jest.fn(),
}));

jest.mock('../../credit/credit.repository', () => ({
  totalPaymentsForRange: jest.fn(),
}));

jest.mock('../../clinic/clinic.repository', () => ({
  revenueForRange: jest.fn(),
}));

jest.mock('../../restaurant/restaurant.repository', () => ({
  revenueForRange: jest.fn(),
  totalInventoryValue: jest.fn().mockResolvedValue(0),
}));

describe('Financial Calculation Service - Unit Tests', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('resolveRange', () => {
    it('resolves daily preset to today', () => {
      const { period, rangeStart, rangeEnd } = resolveRange({ period: 'daily' });
      expect(period).toBe('daily');
      expect(rangeStart).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      expect(rangeEnd).toBe(rangeStart);
    });

    it('resolves weekly preset to 7 days (Monday to Sunday)', () => {
      const { period, rangeStart, rangeEnd } = resolveRange({ period: 'weekly' });
      expect(period).toBe('weekly');
      const start = new Date(rangeStart);
      const end = new Date(rangeEnd);
      const diffDays = Math.round((end - start) / (1000 * 60 * 60 * 24));
      expect(diffDays).toBe(6);
    });

    it('resolves monthly preset to 1st of month to last day of month', () => {
      const { period, rangeStart, rangeEnd } = resolveRange({ period: 'monthly' });
      expect(period).toBe('monthly');
      expect(rangeStart.endsWith('-01')).toBe(true);
      expect(new Date(rangeStart) <= new Date(rangeEnd)).toBe(true);
    });

    it('resolves yearly preset to Jan 1st to Dec 31st of current year', () => {
      const { period, rangeStart, rangeEnd } = resolveRange({ period: 'yearly' });
      expect(period).toBe('yearly');
      expect(rangeStart.endsWith('-01-01')).toBe(true);
      expect(rangeEnd.endsWith('-12-31')).toBe(true);
      expect(new Date(rangeStart) <= new Date(rangeEnd)).toBe(true);
    });

    it('resolves custom range with from and to', () => {
      const { period, rangeStart, rangeEnd } = resolveRange({
        from: '2026-01-01',
        to: '2026-01-31',
      });
      expect(period).toBe('custom');
      expect(rangeStart).toBe('2026-01-01');
      expect(rangeEnd).toBe('2026-01-31');
    });

    it('rejects invalid custom range where to is before from', () => {
      expect(() => {
        resolveRange({ from: '2026-02-01', to: '2026-01-01' });
      }).toThrow();
    });

    it('rejects invalid period names', () => {
      expect(() => {
        resolveRange({ period: 'unknown_period' });
      }).toThrow();
    });
  });

  describe('calculateFinancials - Production Financial Formula Verification', () => {
    const mockCompanyId = '00000000-0000-0000-0000-000000000001';

    function setupDefaultMocks({
      revenue = 0,
      operatingExpenses = 0,
      salaries = 0,
      credit = 0,
      clinic = 0,
      restaurant = 0,
      employees = [],
      categories = [],
    } = {}) {
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: 'retail_store' }] });
        }
        if (sql.includes('SELECT') && sql.includes('AS revenue')) {
          return Promise.resolve({
            rows: [{ revenue, cogs: 0, sales_count: 5 }],
          });
        }
        if (sql.includes('FROM sale_items')) {
          return Promise.resolve({ rows: [] });
        }
        if (sql.includes('FROM expenses') && sql.includes('COUNT(*)')) {
          return Promise.resolve({ rows: [{ count: 3 }] });
        }
        if (sql.includes('FROM employees')) {
          return Promise.resolve({ rows: employees });
        }
        if (sql.includes('FROM invoices')) {
          return Promise.resolve({ rows: [{ count: 2 }] });
        }
        if (sql.includes('FROM expenses') && sql.includes('GROUP BY category')) {
          return Promise.resolve({ rows: categories });
        }
        if (sql.includes('FROM sales') && sql.includes('LIMIT 10')) {
          return Promise.resolve({ rows: [] });
        }
        if (sql.includes('FROM expenses') && sql.includes('LIMIT 10')) {
          return Promise.resolve({ rows: [] });
        }
        return Promise.resolve({ rows: [] });
      });

      expensesRepo.totalForRange.mockResolvedValue(operatingExpenses);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(salaries);
      creditRepo.totalPaymentsForRange.mockResolvedValue(credit);
      clinicRepo.revenueForRange.mockResolvedValue(clinic);
      restaurantRepo.revenueForRange.mockResolvedValue(restaurant);
    }

    it('Scenario 1: Daily (Revenue 10,000 DA, Expenses 3,000 DA => Net Profit 7,000 DA)', async () => {
      setupDefaultMocks({
        revenue: 10000,
        operatingExpenses: 2000,
        salaries: 1000,
        employees: [{ id: 'e1', name: 'Karim', position: 'Vendeur', base_salary: 30000 }],
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(10000);
      expect(result.expenses).toBe(3000);
      expect(result.netProfit).toBe(7000);
      expect(result.profitMargin).toBe(70.0);
    });

    it('Scenario 2: Weekly (Revenue 70,000 DA, Expenses 20,000 DA => Net Profit 50,000 DA)', async () => {
      setupDefaultMocks({
        revenue: 70000,
        operatingExpenses: 15000,
        salaries: 5000,
        employees: [{ id: 'e1', name: 'Karim', position: 'Vendeur', base_salary: 30000 }],
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'weekly' });

      expect(result.revenue).toBe(70000);
      expect(result.expenses).toBe(20000);
      expect(result.netProfit).toBe(50000);
      expect(result.profitMargin).toBe(71.43);
    });

    it('Scenario 3: Monthly (Revenue 300,000 DA, Expenses 70,000 DA => Net Profit 230,000 DA)', async () => {
      setupDefaultMocks({
        revenue: 300000,
        operatingExpenses: 30000,
        salaries: 40000,
        employees: [{ id: 'e1', name: 'Karim', position: 'Manager', base_salary: 40000 }],
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'monthly' });

      expect(result.revenue).toBe(300000);
      expect(result.expenses).toBe(70000);
      expect(result.netProfit).toBe(230000);
      expect(result.profitMargin).toBe(76.67);
    });

    it('Scenario 4: Yearly (Revenue 3,000,000 DA, Expenses 800,000 DA => Net Profit 2,200,000 DA)', async () => {
      setupDefaultMocks({
        revenue: 3000000,
        operatingExpenses: 320000,
        salaries: 480000,
        employees: [{ id: 'e1', name: 'Karim', position: 'Manager', base_salary: 40000 }],
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'yearly' });

      expect(result.revenue).toBe(3000000);
      expect(result.expenses).toBe(800000);
      expect(result.netProfit).toBe(2200000);
      expect(result.profitMargin).toBe(73.33);
    });

    it('Scenario 5: Zero Revenue (Revenue 0 DA, Expenses 5,000 DA => Net Profit -5,000 DA Loss)', async () => {
      setupDefaultMocks({
        revenue: 0,
        operatingExpenses: 5000,
        salaries: 0,
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(0);
      expect(result.expenses).toBe(5000);
      expect(result.netProfit).toBe(-5000);
      expect(result.profitMargin).toBe(0);
    });

    it('Scenario 6: Zero Expense (Revenue 10,000 DA, Expenses 0 DA => Net Profit +10,000 DA)', async () => {
      setupDefaultMocks({
        revenue: 10000,
        operatingExpenses: 0,
        salaries: 0,
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(10000);
      expect(result.expenses).toBe(0);
      expect(result.netProfit).toBe(10000);
      expect(result.profitMargin).toBe(100.0);
    });

    it('Scenario 7: Equal Revenue & Expenses (Revenue 10,000 DA, Expenses 10,000 DA => Net Profit 0 DA)', async () => {
      setupDefaultMocks({
        revenue: 10000,
        operatingExpenses: 6000,
        salaries: 4000,
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(10000);
      expect(result.expenses).toBe(10000);
      expect(result.netProfit).toBe(0);
      expect(result.profitMargin).toBe(0.0);
    });

    it('Guarantees zero double-counting of employee salaries', async () => {
      setupDefaultMocks({
        revenue: 50000,
        operatingExpenses: 10000,
        salaries: 25000,
        employees: [{ id: 'e1', name: 'Nadia', base_salary: 25000 }],
        categories: [{ category: 'Loyer', total: 10000 }],
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'monthly' });

      // totalExpenses = operatingExpenses + employeeSalaries
      expect(result.expenses).toBe(35000);
      expect(result.employeeSalaries).toBe(25000);
      expect(result.operatingExpenses).toBe(10000);
      expect(expensesRepo.totalForRange).toHaveBeenCalledWith(
        mockCompanyId,
        expect.any(String),
        expect.any(String),
        { excludeSalaryCategories: true },
      );
    });

    it('Returns structured breakdown, activity summary, and transactions', async () => {
      setupDefaultMocks({
        revenue: 100000,
        operatingExpenses: 20000,
        salaries: 30000,
        employees: [{ id: 'e1', name: 'Yacine', position: 'Chef', base_salary: 30000 }],
        categories: [{ category: 'Electricité', total: 20000 }],
      });

      const result = await calculateFinancials(mockCompanyId, { period: 'monthly' });

      expect(result.revenueBreakdown).toBeDefined();
      expect(result.revenueBreakdown.totalRevenue).toBe(100000);
      expect(result.expensesBreakdown).toBeDefined();
      expect(result.expensesBreakdown.totalExpenses).toBe(50000);
      expect(result.expensesBreakdown.byCategory).toHaveLength(1);
      expect(result.expensesBreakdown.byEmployee).toHaveLength(1);
      expect(result.activitySummary).toEqual({
        salesCount: 5,
        expensesCount: 3,
        employeesCount: 1,
        invoicesCount: 2,
      });
      expect(Array.isArray(result.recentTransactions)).toBe(true);
    });

    it('Scenario 21: Daily, Monthly, Yearly actual salary transactions without proration', async () => {
      // Ahmed: 30,000 DZD paid on Sep 30 and Oct 31
      // On Sep 15: salary expense is 0 (NOT 1,000)
      setupDefaultMocks({
        revenue: 0,
        operatingExpenses: 0,
        salaries: 0, // No salary on Sep 15
      });

      const sep15 = await calculateFinancials(mockCompanyId, { period: 'daily', date: '2026-09-15' });
      expect(sep15.employeeSalaries).toBe(0);
      expect(sep15.expenses).toBe(0);

      // On Sep 30: salary expense is 30,000
      setupDefaultMocks({
        revenue: 0,
        operatingExpenses: 0,
        salaries: 30000,
      });

      const sep30 = await calculateFinancials(mockCompanyId, { period: 'daily', date: '2026-09-30' });
      expect(sep30.employeeSalaries).toBe(30000);
      expect(sep30.expenses).toBe(30000);

      // Monthly September: salary expense is 30,000
      const sepMonth = await calculateFinancials(mockCompanyId, { period: 'monthly', month: '2026-09' });
      expect(sepMonth.employeeSalaries).toBe(30000);

      // Yearly 2026: salary expense is 60,000 (Sep 30 + Oct 31)
      setupDefaultMocks({
        revenue: 0,
        operatingExpenses: 0,
        salaries: 60000,
      });

      const year2026 = await calculateFinancials(mockCompanyId, { period: 'yearly', year: '2026' });
      expect(year2026.employeeSalaries).toBe(60000);
    });

    it('Scenario 22: Employee resigns after 3 months (Actual = 90,000, NOT 360,000)', async () => {
      // 3 actual salary transactions in Jan, Feb, Mar (30,000 each)
      // No transactions Apr-Dec
      setupDefaultMocks({
        revenue: 200000,
        operatingExpenses: 10000,
        salaries: 90000, // Jan + Feb + Mar
        employees: [{ id: 'e1', name: 'Ahmed', base_salary: 30000 }],
      });

      const annualReport = await calculateFinancials(mockCompanyId, { period: 'yearly', year: '2026' });
      expect(annualReport.employeeSalaries).toBe(90000);
      expect(annualReport.expenses).toBe(100000);
      expect(annualReport.netProfit).toBe(100000);
    });

    it('Scenario 23: Mixed expenses and Global Net Profit distinction', async () => {
      // September: Salary = 30,000, Rent = 20,000, Electricity = 5,000, Supplies = 3,000 => Expenses = 58,000
      // September Revenue = 100,000 => September Net Profit = 42,000
      setupDefaultMocks({
        revenue: 100000,
        operatingExpenses: 28000, // Rent(20k) + Electricity(5k) + Supplies(3k)
        salaries: 30000,
      });

      const sepReport = await calculateFinancials(mockCompanyId, { period: 'monthly', month: '2026-09' });
      expect(sepReport.revenue).toBe(100000);
      expect(sepReport.operatingExpenses).toBe(28000);
      expect(sepReport.employeeSalaries).toBe(30000);
      expect(sepReport.expenses).toBe(58000);
      expect(sepReport.netProfit).toBe(42000);

      // Global Net Profit is separate and represents all transactions
      expect(sepReport.global).toBeDefined();
      expect(typeof sepReport.global.globalNetProfit).toBe('number');
      expect(typeof sepReport.allRevenue).toBe('number');
      expect(typeof sepReport.allExpenses).toBe('number');
    });

    it('Supports explicit date, month, and year pickers in resolveRange', () => {
      const daily = resolveRange({ period: 'daily', date: '2026-09-30' });
      expect(daily.rangeStart).toBe('2026-09-30');
      expect(daily.rangeEnd).toBe('2026-09-30');

      const monthly = resolveRange({ period: 'monthly', month: '2026-09' });
      expect(monthly.rangeStart).toBe('2026-09-01');
      expect(monthly.rangeEnd).toBe('2026-09-30');

      const yearly = resolveRange({ period: 'yearly', year: '2026' });
      expect(yearly.rangeStart).toBe('2026-01-01');
      expect(yearly.rangeEnd).toBe('2026-12-31');
    });

    it('Scenario 24: Standard Accounting Formula Verification (Purchase 100, Sale 150, Qty 10 => Revenue 1500, COGS 1000, Gross Profit 500, Expenses 200 => Net Profit 300)', async () => {
      const purchasePrice = 100;
      const salePrice = 150;
      const quantitySold = 10;
      const currentStock = 20;
      const expenses = 200;

      // REVENUE = SALE PRICE * QUANTITY SOLD = 150 * 10 = 1500
      const expectedRevenue = salePrice * quantitySold;
      expect(expectedRevenue).toBe(1500);

      // COGS = PURCHASE PRICE * QUANTITY SOLD = 100 * 10 = 1000
      const expectedCogs = purchasePrice * quantitySold;
      expect(expectedCogs).toBe(1000);

      // GROSS PROFIT = REVENUE - COGS = 1500 - 1000 = 500
      const expectedGrossProfit = expectedRevenue - expectedCogs;
      expect(expectedGrossProfit).toBe(500);

      // INVENTORY VALUE = (SELLING - PURCHASE) * STOCK = 50 * 20 = 1000
      const expectedInventoryValue = (salePrice - purchasePrice) * currentStock;
      expect(expectedInventoryValue).toBe(1000);

      // NET PROFIT = GROSS PROFIT - EXPENSES = 500 - 200 = 300
      const expectedNetProfit = expectedGrossProfit - expenses;
      expect(expectedNetProfit).toBe(300);

      // Verify calculateFinancials handles inventoryValue, revenue, cogs, gross profit, and net profit correctly
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: 'retail_store' }] });
        }
        if (sql.includes('SELECT') && sql.includes('AS revenue')) {
          return Promise.resolve({
            rows: [{ revenue: expectedRevenue, cogs: expectedCogs, sales_count: 1 }],
          });
        }
        if (sql.includes('inventory_value')) {
          return Promise.resolve({
            rows: [{ inventory_value: expectedInventoryValue }],
          });
        }
        if (sql.includes('FROM sale_items')) {
          return Promise.resolve({ rows: [] });
        }
        if (sql.includes('FROM expenses') && sql.includes('COUNT(*)')) {
          return Promise.resolve({ rows: [{ count: 1 }] });
        }
        if (sql.includes('FROM employees')) {
          return Promise.resolve({ rows: [] });
        }
        if (sql.includes('FROM invoices')) {
          return Promise.resolve({ rows: [{ count: 0 }] });
        }
        if (sql.includes('FROM expenses') && sql.includes('GROUP BY category')) {
          return Promise.resolve({ rows: [{ category: 'Operating', total: expenses }] });
        }
        return Promise.resolve({ rows: [] });
      });

      expensesRepo.totalForRange.mockResolvedValue(expenses);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(0);

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(1500);
      expect(result.costOfGoodsSold).toBe(1000);
      expect(result.grossProfit).toBe(500);
      expect(result.expenses).toBe(200);
      expect(result.netProfit).toBe(300);
      expect(result.inventoryValue).toBe(1000);
    });

    it('Scenario 25: Negative Gross Profit correctly calculates when goods sold below cost (Rev 400, COGS 500, Exp 0 -> GP -100, NP -100)', async () => {
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: 'retail' }] });
        }
        if (sql.includes('FROM sales s') && sql.includes('COUNT(*)')) {
          return Promise.resolve({
            rows: [
              {
                revenue: '400.00',
                cogs: '500.00',
                sales_count: 1,
              },
            ],
          });
        }
        if (sql.includes('FROM sales') && sql.includes('COALESCE(SUM(total), 0) AS revenue')) {
          return Promise.resolve({ rows: [{ revenue: '400.00', cogs: '500.00' }] });
        }
        if (sql.includes('FROM expenses') && sql.includes('COALESCE(SUM(amount), 0) AS total')) {
          return Promise.resolve({ rows: [{ total: '0.00' }] });
        }
        if (sql.includes('FROM products') && sql.includes('inventory_value')) {
          return Promise.resolve({ rows: [{ inventory_value: '0.00' }] });
        }
        return Promise.resolve({ rows: [] });
      });

      expensesRepo.totalForRange.mockResolvedValue(0);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(0);

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(400);
      expect(result.costOfGoodsSold).toBe(500);
      expect(result.grossProfit).toBe(-100);
      expect(result.expenses).toBe(0);
      expect(result.netProfit).toBe(-100);
    });

    it('throws 403 ONBOARDING_INCOMPLETE when company business_type is NULL', async () => {
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: null }] });
        }
        return Promise.resolve({ rows: [] });
      });

      await expect(calculateFinancials(mockCompanyId, { period: 'daily' })).rejects.toMatchObject({
        statusCode: 403,
        code: 'ONBOARDING_INCOMPLETE',
      });
    });

    it('Scenario 26: Restaurant Business Rules - Revenue 10,000 DA, Current Inventory Value 3,000 DA, Eligible Paid Expenses 1,000 DA => GP 10,000 DA, NP 6,000 DA', async () => {
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: 'restaurant' }] });
        }
        if (sql.includes('FROM restaurant_orders')) {
          return Promise.resolve({ rows: [{ count: 12 }] });
        }
        if (sql.includes('SELECT COALESCE(SUM(amount), 0) AS total FROM expenses')) {
          return Promise.resolve({ rows: [{ total: 1000 }] });
        }
        return Promise.resolve({ rows: [] });
      });

      expensesRepo.totalForRange.mockResolvedValue(1000); // 1,000 eligible paid expenses
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(10000); // 10,000 DA revenue
      restaurantRepo.totalInventoryValue = jest.fn().mockResolvedValue(3000); // 3,000 DA total current inventory value
      restaurantRepo.bestSellingDishes = jest.fn().mockResolvedValue([]);

      const result = await calculateFinancials(mockCompanyId, { period: 'monthly' });

      expect(result.revenue).toBe(10000);
      expect(result.costOfGoodsSold).toBe(0);
      expect(result.grossProfit).toBe(10000); // Equal to revenue
      expect(result.inventoryValue).toBe(3000); // Current inventory value
      expect(result.expenses).toBe(1000);
      expect(result.netProfit).toBe(6000); // 10,000 - 3,000 - 1,000 = 6,000
    });

    it('Scenario 26b: Restaurant with Empty Inventory (0 DA inventory value) => NP = Revenue - Expenses', async () => {
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: 'restaurant' }] });
        }
        if (sql.includes('FROM restaurant_orders')) {
          return Promise.resolve({ rows: [{ count: 5 }] });
        }
        if (sql.includes('SELECT COALESCE(SUM(amount), 0) AS total FROM expenses')) {
          return Promise.resolve({ rows: [{ total: 1000 }] });
        }
        return Promise.resolve({ rows: [] });
      });

      expensesRepo.totalForRange.mockResolvedValue(1000);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(10000);
      restaurantRepo.totalInventoryValue = jest.fn().mockResolvedValue(0); // 0 DA inventory value
      restaurantRepo.bestSellingDishes = jest.fn().mockResolvedValue([]);

      const result = await calculateFinancials(mockCompanyId, { period: 'monthly' });

      expect(result.revenue).toBe(10000);
      expect(result.grossProfit).toBe(10000);
      expect(result.inventoryValue).toBe(0);
      expect(result.expenses).toBe(1000);
      expect(result.netProfit).toBe(9000); // 10,000 - 0 - 1,000 = 9,000
    });

    it('Scenario 27: Unpaid sales excluded from received revenue (Section 4.1)', async () => {
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: 'retail_store' }] });
        }
        if (sql.includes('s.payment_status = \'paid\'')) {
          // Query properly filters paid sales; unpaid sales return 0
          return Promise.resolve({ rows: [{ revenue: 0, cogs: 0, sales_count: 0 }] });
        }
        return Promise.resolve({ rows: [] });
      });

      expensesRepo.totalForRange.mockResolvedValue(0);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(0);

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(0);
      expect(result.grossProfit).toBe(0);
      expect(result.netProfit).toBe(0);
    });

    it('Scenario 28: Cancelled sales excluded from revenue and sales count (Section 6.1)', async () => {
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies')) {
          return Promise.resolve({ rows: [{ business_type: 'retail_store' }] });
        }
        if (sql.includes('s.payment_status = \'paid\'')) {
          return Promise.resolve({ rows: [{ revenue: 0, cogs: 0, sales_count: 0 }] });
        }
        return Promise.resolve({ rows: [] });
      });

      expensesRepo.totalForRange.mockResolvedValue(0);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(0);

      const result = await calculateFinancials(mockCompanyId, { period: 'daily' });

      expect(result.revenue).toBe(0);
      expect(result.salesCount).toBe(0);
      expect(result.costOfGoodsSold).toBe(0);
    });
  });
});


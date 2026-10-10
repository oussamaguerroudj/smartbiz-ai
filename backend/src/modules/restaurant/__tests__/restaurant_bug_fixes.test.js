const { validateRecordPayment } = require('../restaurant.validators');
const financialService = require('../../financial/financial.service');
const { query } = require('../../../config/db');
const restaurantRepo = require('../restaurant.repository');
const expensesRepo = require('../../expenses/expenses.repository');
const employeesRepo = require('../../employees/employees.repository');
const creditRepo = require('../../credit/credit.repository');
const clinicRepo = require('../../clinic/clinic.repository');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
  withTransaction: jest.fn((cb) => cb({ query: jest.fn() })),
}));

jest.mock('../restaurant.repository');
jest.mock('../../expenses/expenses.repository');
jest.mock('../../employees/employees.repository');
jest.mock('../../credit/credit.repository');
jest.mock('../../clinic/clinic.repository');

expensesRepo.salariesBreakdownForRange = jest.fn().mockResolvedValue([]);

describe('Restaurant & Multi-Tenant Bug Fixes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Bug R1: Restaurant Payment Method Validation', () => {
    test('rejects card payment method with INVALID_PAYMENT_METHOD', () => {
      const req = { body: { amount: 1000, method: 'card' } };
      let err;
      const next = (e) => { err = e; };

      validateRecordPayment(req, {}, next);

      expect(err).toBeDefined();
      expect(err.statusCode).toBe(400);
      expect(err.code).toBe('INVALID_PAYMENT_METHOD');
      expect(err.message).toContain('Direct payment only');
    });

    test('rejects any non-direct payment method with INVALID_PAYMENT_METHOD', () => {
      const req = { body: { amount: 1000, method: 'bank_transfer' } };
      let err;
      const next = (e) => { err = e; };

      validateRecordPayment(req, {}, next);

      expect(err).toBeDefined();
      expect(err.statusCode).toBe(400);
      expect(err.code).toBe('INVALID_PAYMENT_METHOD');
    });

    test('accepts cash payment method', () => {
      const req = { body: { amount: 1000, method: 'cash' } };
      let err = null;
      const next = (e) => { err = e; };

      validateRecordPayment(req, {}, next);

      expect(err).toBeUndefined();
    });

    test('accepts direct payment method', () => {
      const req = { body: { amount: 1000, method: 'direct' } };
      let err = null;
      const next = (e) => { err = e; };

      validateRecordPayment(req, {}, next);

      expect(err).toBeUndefined();
    });
  });

  describe('Restaurant Financial Calculation vs Non-Restaurant Isolation', () => {
    const companyId = '11111111-1111-1111-1111-111111111111';

    test('Restaurant (Section 5): Gross Profit = Revenue (10000), Net Profit = Revenue (10000) - Expenses (4000) = 6000', async () => {
      // 1. Company query: business_type = 'restaurant'
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies WHERE id = $1')) {
          return Promise.resolve({ rows: [{ business_type: 'restaurant' }] });
        }
        if (sql.includes('SELECT COALESCE(SUM(amount), 0) AS total FROM expenses')) {
          return Promise.resolve({ rows: [{ total: 4000 }] });
        }
        if (sql.includes('FROM sale_items si')) {
          return Promise.resolve({ rows: [{ revenue: 0 }] });
        }
        if (sql.includes('FROM products WHERE company_id = $1')) {
          return Promise.resolve({ rows: [{ inventory_value: 0 }] });
        }
        if (sql.includes('FROM restaurant_orders WHERE company_id = $1')) {
          return Promise.resolve({ rows: [{ count: 1 }] });
        }
        if (sql.includes('FROM invoices WHERE company_id = $1')) {
          return Promise.resolve({ rows: [{ count: 1 }] });
        }
        if (sql.includes('expenses WHERE company_id = $1 AND deleted_at IS NULL')) {
          return Promise.resolve({ rows: [] });
        }
        if (sql.includes('FROM employees WHERE company_id = $1')) {
          return Promise.resolve({ rows: [] });
        }
        return Promise.resolve({ rows: [] });
      });

      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(10000); // 10,000 DZD sales
      restaurantRepo.bestSellingDishes.mockResolvedValue([]);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      // 3,000 DZD inventory purchase payments + 1,000 DZD other expenses = 4,000 DZD qualifying expenses
      expensesRepo.totalForRange.mockResolvedValue(4000);

      const result = await financialService.calculateFinancials(companyId, { period: 'monthly' });

      expect(result.revenue).toBe(10000);
      expect(result.costOfGoodsSold).toBe(0);
      expect(result.expenses).toBe(4000);
      expect(result.grossProfit).toBe(10000); // Gross Profit = Revenue
      expect(result.netProfit).toBe(6000); // Net Profit = 10000 - 4000 = 6000
    });

    test('Supermarket: Net Profit = Revenue (1000) - Expenses (100) = 900 (COGS not deducted from net profit)', async () => {
      // 1. Company query: business_type = 'supermarket'
      query.mockImplementation((sql) => {
        if (sql.includes('FROM companies WHERE id = $1')) {
          return Promise.resolve({ rows: [{ business_type: 'supermarket' }] });
        }
        if (sql.includes('SELECT COALESCE(SUM(amount), 0) AS total FROM expenses')) {
          return Promise.resolve({ rows: [{ total: 100 }] });
        }
        if (sql.includes('FROM sale_items si') && sql.includes('sales_count')) {
          return Promise.resolve({ rows: [{ revenue: 1000, cogs: 0, sales_count: 5 }] });
        }
        if (sql.includes('FROM sale_items si')) {
          return Promise.resolve({ rows: [{ revenue: 1000 }] });
        }
        if (sql.includes('FROM products WHERE company_id = $1')) {
          return Promise.resolve({ rows: [{ inventory_value: 0 }] });
        }
        if (sql.includes('FROM invoices WHERE company_id = $1')) {
          return Promise.resolve({ rows: [{ count: 5 }] });
        }
        if (sql.includes('expenses WHERE company_id = $1 AND deleted_at IS NULL')) {
          return Promise.resolve({ rows: [] });
        }
        if (sql.includes('FROM employees WHERE company_id = $1')) {
          return Promise.resolve({ rows: [] });
        }
        return Promise.resolve({ rows: [] });
      });

      creditRepo.totalPaymentsForRange.mockResolvedValue(0);
      clinicRepo.revenueForRange.mockResolvedValue(0);
      restaurantRepo.revenueForRange.mockResolvedValue(0);
      employeesRepo.totalSalaryCostForRange.mockResolvedValue(0);
      expensesRepo.totalForRange.mockResolvedValue(100);

      const result = await financialService.calculateFinancials(companyId, { period: 'monthly' });

      expect(result.revenue).toBe(1000);
      expect(result.costOfGoodsSold).toBe(0);
      expect(result.expenses).toBe(100);
      // For Supermarket, netProfit remains 100% unchanged: revenue - expenses = 900
      expect(result.netProfit).toBe(900);
    });
  });

  describe('Bug R2: Invoices Repository Restaurant Order Support', () => {
    const invoicesRepo = require('../../invoices/invoices.repository');

    test('findAll joins restaurant_orders when sale_id is null', async () => {
      const mockRows = [
        {
          id: 'inv-1',
          order_id: 'order-1',
          sale_id: null,
          invoice_number: 'INV-1',
          total: 1500,
          sold_at: '2026-10-08T12:00:00Z',
          customer_name: 'Dine-in Guest',
        },
      ];
      query.mockResolvedValueOnce({ rows: mockRows });

      const results = await invoicesRepo.findAll('comp-1');
      expect(results).toHaveLength(1);
      expect(results[0].total).toBe(1500);
      expect(results[0].customer_name).toBe('Dine-in Guest');
      expect(results[0].order_id).toBe('order-1');
    });
  });

  describe('Bug S1: Products Repository Client ID Support', () => {
    const productsRepo = require('../../products/products.repository');

    test('create passes data.id if provided to prevent duplicate creation', async () => {
      const customId = '22222222-2222-2222-2222-222222222222';
      let capturedParams;
      query.mockImplementation((sql, params) => {
        if (sql.includes('INSERT INTO products')) {
          capturedParams = params;
          return Promise.resolve({ rows: [{ id: customId, name: 'Milk' }] });
        }
        return Promise.resolve({ rows: [] });
      });

      const res = await productsRepo.create('comp-1', {
        id: customId,
        name: 'Milk',
        purchasePrice: 80,
        sellingPrice: 100,
        quantity: 10,
      });

      expect(res.id).toBe(customId);
      expect(capturedParams[0]).toBe(customId);
    });
  });
});

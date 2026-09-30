/**
 * Enterprise vertical (Ch. 19): tenant isolation on every repository
 * query, the shared revenue/expense/profit formula, and validators.
 */

jest.mock('../../../config/db', () => ({ query: jest.fn() }));

const { query } = require('../../../config/db');
const service = require('../enterprise.service');
const repo = require('../enterprise.repository');
const { validateCreateProject, validateProjectStatus } = require('../enterprise.validators');

const COMPANY = '11111111-1111-1111-1111-111111111111';

function rowsFor(sql) {
  if (/FROM sales/.test(sql) && /SUM\(total\)/.test(sql)) return { rows: [{ revenue: '1000', count: 2 }] };
  if (/FROM credit_payments/.test(sql)) return { rows: [{ total: '200' }] };
  if (/expense_prorated_amount/.test(sql)) return { rows: [{ total: '300' }] };
  if (/salary_adjustments|base_salary/.test(sql) && /employees/.test(sql)) return { rows: [{ total: '100' }] };
  return { rows: [{ total: '0', count: 0, revenue: '0' }], rowCount: 0 };
}

beforeEach(() => {
  query.mockReset();
  query.mockImplementation(async (sql) => rowsFor(sql));
});

describe('enterprise.service.getDashboard', () => {
  test('every query binds the company id as the first parameter', async () => {
    await service.getDashboard(COMPANY);
    expect(query).toHaveBeenCalled();
    for (const [, params] of query.mock.calls) {
      expect(params[0]).toBe(COMPANY);
    }
  });

  test('profit = (sales + credit payments) - (operating expenses + payroll)', async () => {
    const fin = await service.financialsForRange(COMPANY, '2026-09-01', '2026-09-19');
    expect(fin.revenue).toBe(fin.invoicedRevenue + fin.creditPayments);
    expect(fin.expenses).toBe(fin.operatingExpenses + fin.payroll);
    expect(fin.netProfit).toBe(fin.revenue - fin.expenses);
  });

  test('a brand-new company returns zeros/empty lists, not errors', async () => {
    // A brand-new company: aggregate queries (SUM/COUNT) still return ONE
    // row of zeros, but list queries (ORDER BY ... LIMIT) return NO rows -
    // exactly what Postgres does. (The earlier version of this mock
    // returned the aggregate row for list queries too, which made
    // `unpaidInvoices` look like [{...}] and failed this test even though
    // the repository code was correct.)
    query.mockImplementation(async (sql) => (
      /LIMIT\s+\$\d/.test(sql)
        ? { rows: [], rowCount: 0 }
        : { rows: [{ total: '0', count: 0, revenue: '0' }], rowCount: 0 }
    ));
    const d = await service.getDashboard(COMPANY);
    expect(d.todayRevenue).toBe(0);
    expect(d.unpaidInvoices).toEqual([]);
    expect(d.projects.total).toBe(0);
  });
});

describe('enterprise projects', () => {
  test('a client from another company cannot be linked', async () => {
    query.mockResolvedValue({ rows: [], rowCount: 0 });
    await expect(service.createProject(COMPANY, { name: 'X', customerId: 'other' })).rejects.toMatchObject({
      statusCode: 400,
    });
  });

  test('status update on an unknown/foreign project is a 404', async () => {
    query.mockResolvedValue({ rows: [], rowCount: 0 });
    await expect(service.updateProjectStatus(COMPANY, 'nope', 'active')).rejects.toMatchObject({ statusCode: 404 });
    expect(query.mock.calls[0][1][0]).toBe(COMPANY);
  });

  test('repository functions scope by company id', async () => {
    query.mockResolvedValue({ rows: [{ id: 'p1' }], rowCount: 1 });
    await repo.listProjects(COMPANY, 'active');
    await repo.openProjects(COMPANY, 3);
    await repo.projectSummary(COMPANY);
    for (const [, params] of query.mock.calls) expect(params[0]).toBe(COMPANY);
  });
});

describe('enterprise validators', () => {
  const run = (fn, body) => {
    const next = jest.fn();
    fn({ body }, {}, next);
    return next.mock.calls[0][0];
  };

  test('create project requires a name', () => {
    expect(run(validateCreateProject, {})).toMatchObject({ statusCode: 400 });
    expect(run(validateCreateProject, { name: 'Site A' })).toBeUndefined();
  });

  test('rejects negative budget, bad dates and due before start', () => {
    expect(run(validateCreateProject, { name: 'A', budget: -1 })).toMatchObject({ statusCode: 400 });
    expect(run(validateCreateProject, { name: 'A', dueDate: '19/09/2026' })).toMatchObject({ statusCode: 400 });
    expect(run(validateCreateProject, { name: 'A', startDate: '2026-09-10', dueDate: '2026-09-01' })).toMatchObject({
      statusCode: 400,
    });
  });

  test('status must be a known value', () => {
    expect(run(validateProjectStatus, { status: 'bogus' })).toMatchObject({ statusCode: 400 });
    expect(run(validateProjectStatus, { status: 'on_hold' })).toBeUndefined();
  });
});

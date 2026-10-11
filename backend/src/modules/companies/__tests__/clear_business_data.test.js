const bcrypt = require('bcryptjs');
const { clearBusinessDataHandler } = require('../companies.routes');
const { query, withTransaction } = require('../../../config/db');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
  withTransaction: jest.fn((cb) => cb({ query: jest.fn().mockResolvedValue({ rows: [] }) })),
}));

describe('Clear Business Data Endpoint', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects if password is empty or missing', async () => {
    const req = {
      user: { id: 'user-1', companyId: 'comp-1', role: 'owner' },
      body: {},
    };
    const res = {};
    const next = jest.fn();

    await clearBusinessDataHandler(req, res, next);
    expect(next).toHaveBeenCalled();
    const error = next.mock.calls[0][0];
    expect(error.code).toBe('VALIDATION_ERROR');
  });

  it('rejects if password does not match user password hash', async () => {
    const correctHash = await bcrypt.hash('CorrectSecret123', 8);
    query.mockResolvedValueOnce({
      rows: [
        { id: 'user-1', company_id: 'comp-1', password_hash: correctHash },
      ],
    });

    const req = {
      user: { id: 'user-1', companyId: 'comp-1', role: 'owner' },
      body: { password: 'WrongPassword' },
    };
    const res = {};
    const next = jest.fn();

    await clearBusinessDataHandler(req, res, next);
    expect(next).toHaveBeenCalled();
    const error = next.mock.calls[0][0];
    expect(error.code).toBe('INVALID_PASSWORD');
  });

  it('successfully clears company business data within transaction when password matches', async () => {
    const correctHash = await bcrypt.hash('CorrectSecret123', 8);
    query.mockResolvedValueOnce({
      rows: [
        { id: 'user-1', company_id: 'comp-1', password_hash: correctHash },
      ],
    });

    const mockClientQuery = jest.fn().mockImplementation(async (sql) => {
      if (typeof sql === 'string' && sql.includes('information_schema.tables')) {
        return {
          rows: [
            { table_name: 'invoices' },
            { table_name: 'sale_items' },
            { table_name: 'sales' },
            { table_name: 'customer_debts' },
            { table_name: 'credit_transactions' },
            { table_name: 'customers' },
            { table_name: 'expenses' },
            { table_name: 'purchase_items' },
            { table_name: 'purchases' },
            { table_name: 'products' },
            { table_name: 'suppliers' },
            { table_name: 'sync_queue' },
          ],
        };
      }
      return { rows: [] };
    });
    withTransaction.mockImplementationOnce(async (cb) => {
      return cb({ query: mockClientQuery });
    });

    const req = {
      user: { id: 'user-1', companyId: 'comp-1', role: 'owner' },
      body: { password: 'CorrectSecret123' },
    };
    const res = {
      json: jest.fn(),
    };
    const next = jest.fn();

    await clearBusinessDataHandler(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        companyId: 'comp-1',
      }),
    );

    // Verify all deletion queries strictly filtered by companyId 'comp-1'
    const queryCalls = mockClientQuery.mock.calls;
    expect(queryCalls.length).toBeGreaterThan(5);
    for (const [sql, params] of queryCalls) {
      if (typeof sql === 'string' && sql.includes('DELETE FROM')) {
        expect(params).toContain('comp-1');
        // Must never delete from companies or users tables
        expect(sql).not.toContain('DELETE FROM companies');
        expect(sql).not.toContain('DELETE FROM users');
      }
    }
  });
});

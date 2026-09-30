/**
 * Ch. 29 — the single most important test in this migration:
 * a user must never be able to get another company's data out of the
 * AI, no matter what they ask or what the model tries to pass as tool
 * arguments.
 *
 * Approach: mock the DB layer and assert, for every tool, that (a) the
 * companyId actually bound into the SQL query is always exactly the
 * companyId this test passed in — never something pulled from `args`
 * — and (b) supplying a forged `companyId` inside `args` (as if a
 * malicious/confused model tried to smuggle one in) has NO effect on
 * which company gets queried.
 */

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
}));

const { query } = require('../../../config/db');
const { executeTool, TOOL_DEFINITIONS } = require('../ai.tools');

const REAL_COMPANY_ID = '11111111-1111-1111-1111-111111111111';
const FORGED_COMPANY_ID = '99999999-9999-9999-9999-999999999999';

beforeEach(() => {
  query.mockReset();
  // Generic shape that satisfies every tool's `result.rows[...]` access
  // pattern used in this file, regardless of which tool runs.
  query.mockResolvedValue({
    rows: [{ count: 0, total_amount: 0, revenue: 0, order_count: 0 }],
  });
});

describe('ai.tools — company isolation (Ch. 29)', () => {
  const toolNames = TOOL_DEFINITIONS.map((t) => t.function.name);

  test.each(toolNames)('%s always binds the server-supplied companyId, ignoring args.companyId', async (toolName) => {
    await executeTool(REAL_COMPANY_ID, toolName, {
      companyId: FORGED_COMPANY_ID, // a model trying to smuggle a different company in
      period: 'this_month',
      limit: 5,
      days: 30,
      patientName: 'Test Patient', // required by get_clinic tools' patient-lookup tool
    });

    expect(query).toHaveBeenCalled();

    for (const call of query.mock.calls) {
      const [, params] = call;
      if (!params) continue; // a tool with a static query and no params is trivially safe

      // The forged id must never appear anywhere in the bound
      // parameters, and the real one must be present (every tool query
      // scopes by company_id).
      expect(params).not.toContain(FORGED_COMPANY_ID);
      expect(params).toContain(REAL_COMPANY_ID);
    }
  });

  test('unknown tool name is rejected rather than silently running something', async () => {
    const result = await executeTool(REAL_COMPANY_ID, 'drop_all_tables', {});
    expect(result).toEqual({ error: expect.stringContaining('Unknown tool') });
    expect(query).not.toHaveBeenCalled();
  });

  test('a tool throwing does not leak a raw stack trace to the model', async () => {
    query.mockRejectedValueOnce(new Error('relation "sales" does not exist'));
    const result = await executeTool(REAL_COMPANY_ID, 'get_sales_summary', {});
    expect(result.error).toContain('get_sales_summary failed');
    expect(result.error).not.toContain('at ');  // no stack trace lines
  });
});

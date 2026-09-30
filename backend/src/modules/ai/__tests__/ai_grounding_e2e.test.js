jest.mock('../../../config/db', () => ({
  query: jest.fn(),
}));

const mockCreate = jest.fn();

jest.mock('openai', () => {
  return jest.fn().mockImplementation(() => ({
    chat: {
      completions: {
        create: mockCreate,
      },
    },
  }));
});

const { query } = require('../../../config/db');
const service = require('../ai.service');

const COMPANY_ID = '11111111-1111-1111-1111-111111111111';
const USER_ID = '22222222-2222-2222-2222-222222222222';

describe('ai.service.chat — end-to-end database grounding and anti-hallucination', () => {
  beforeEach(() => {
    query.mockReset();
    mockCreate.mockReset();
  });

  test('Arabic question about milk returns exact database quantity without hallucination', async () => {
    // 1. checkRateLimit
    query.mockResolvedValueOnce({ rows: [{ count: 1 }] });
    // 2. company info
    query.mockResolvedValueOnce({
      rows: [{ name: 'Amine Grocery', business_type: 'grocery', currency: 'دج' }],
    });
    // 3. search_products executed by proactive intent for "الحليب"
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'prod-milk-uuid',
          name: 'hlib',
          category: 'Dairy',
          barcode: '6130001',
          quantity: 79,
          minimum_stock: 5,
          purchase_price: '120.00',
          selling_price: '180.00',
          size: null,
          color: null,
          brand: null,
        },
      ],
    });
    // Mock Qwen natural language formatting
    mockCreate.mockResolvedValueOnce({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'لديكم 79 وحدة من الحليب (hlib) متوفرة في المخزون.',
          },
        },
      ],
    });
    // 4. logAi query
    query.mockResolvedValueOnce({ rows: [{ id: 'log-1' }] });

    const result = await service.chat({
      companyId: COMPANY_ID,
      userId: USER_ID,
      message: 'كم لدينا من الحليب؟',
      history: [],
    });

    expect(result).toHaveProperty('reply');
    expect(result.reply).toContain('79');
    expect(result.reply).not.toMatch(/[\u4e00-\u9fa5]/); // zero Chinese
    expect(result.reply).toMatch(/[\u0600-\u06FF]/); // Arabic response
  });

  test('Product not in database returns "لم أجد هذا المنتج" without calling LLM to guess', async () => {
    // 1. checkRateLimit
    query.mockResolvedValueOnce({ rows: [{ count: 1 }] });
    // 2. company info
    query.mockResolvedValueOnce({
      rows: [{ name: 'Amine Grocery', business_type: 'grocery', currency: 'دج' }],
    });
    // 3. search_products returns 0 rows (not found)
    query.mockResolvedValueOnce({ rows: [] });
    // fallback check for restaurant items
    query.mockResolvedValueOnce({ rows: [] });
    // fallback check for restaurant inventory items
    query.mockResolvedValueOnce({ rows: [] });
    // 4. logAi query
    query.mockResolvedValueOnce({ rows: [{ id: 'log-2' }] });

    const result = await service.chat({
      companyId: COMPANY_ID,
      userId: USER_ID,
      message: 'هل المنتج كوكاكولا زيرو متوفر في المخزون؟',
      history: [],
    });

    expect(result.reply).toContain('لم أجد أي منتج مطابق');
    expect(result.reply).not.toMatch(/\d+\s*(?:وحدة|قطع|علب)/); // zero invented quantity
    // Crucial: LLM was never asked to guess
    expect(mockCreate).not.toHaveBeenCalled();
  });

  test('French question about stock returns French response with exact database records', async () => {
    // 1. checkRateLimit
    query.mockResolvedValueOnce({ rows: [{ count: 1 }] });
    // 2. company info
    query.mockResolvedValueOnce({
      rows: [{ name: 'Amine Grocery', business_type: 'grocery', currency: 'DZD' }],
    });
    // 3. search_products executed for "lait"
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'prod-milk-uuid',
          name: 'hlib',
          category: 'Dairy',
          barcode: '6130001',
          quantity: 79,
          minimum_stock: 5,
          purchase_price: '120.00',
          selling_price: '180.00',
        },
      ],
    });
    mockCreate.mockResolvedValueOnce({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'Vous avez actuellement 79 unités de lait en stock au prix de 180 DZD.',
          },
        },
      ],
    });
    // 4. logAi
    query.mockResolvedValueOnce({ rows: [{ id: 'log-3' }] });

    const result = await service.chat({
      companyId: COMPANY_ID,
      userId: USER_ID,
      message: 'Combien avons-nous de lait ?',
      history: [],
    });

    expect(result.reply).toContain('79');
    expect(result.reply).toContain('180');
    expect(result.reply).toContain('stock');
    expect(result.reply).not.toMatch(/[\u4e00-\u9fa5]/); // zero Chinese
  });

  test('Anti-hallucination validation catches and overwrites invented numbers from LLM', async () => {
    // 1. checkRateLimit
    query.mockResolvedValueOnce({ rows: [{ count: 1 }] });
    // 2. company info
    query.mockResolvedValueOnce({
      rows: [{ name: 'Amine Grocery', business_type: 'grocery', currency: 'دج' }],
    });
    // 3. search_products returns quantity: 79
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'prod-milk-uuid',
          name: 'hlib',
          category: 'Dairy',
          barcode: '6130001',
          quantity: 79,
          minimum_stock: 5,
          purchase_price: '120.00',
          selling_price: '180.00',
        },
      ],
    });
    // LLM hallucinates an invented number (e.g. 50 instead of 79)
    mockCreate.mockResolvedValueOnce({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'لدينا 50 وحدة من الحليب في المخزن.',
          },
        },
      ],
    });
    // 4. logAi
    query.mockResolvedValueOnce({ rows: [{ id: 'log-4' }] });

    const result = await service.chat({
      companyId: COMPANY_ID,
      userId: USER_ID,
      message: 'كم لدينا من الحليب؟',
      history: [],
    });

    // The validator MUST have caught the hallucination and forced the database truth (79)
    expect(result.reply).toContain('79');
    expect(result.reply).not.toContain('50');
  });

  test('Inventory summary question retrieves exact total products and units', async () => {
    // 1. checkRateLimit
    query.mockResolvedValueOnce({ rows: [{ count: 1 }] });
    // 2. company info
    query.mockResolvedValueOnce({
      rows: [{ name: 'Amine Grocery', business_type: 'grocery', currency: 'دج' }],
    });
    // 3. get_inventory_summary executed
    query.mockResolvedValueOnce({
      rows: [
        {
          total_products: 4,
          total_units: 148,
          out_of_stock: 1,
          low_stock: 1,
          total_inventory_value: '25400.00',
          total_cost_value: '18200.00',
        },
      ],
    });
    mockCreate.mockResolvedValueOnce({
      choices: [
        {
          message: {
            role: 'assistant',
            content: 'لديك 4 منتجات مسجلة في النظام بإجمالي 148 وحدة في المخزون.',
          },
        },
      ],
    });
    // 4. logAi
    query.mockResolvedValueOnce({ rows: [{ id: 'log-5' }] });

    const result = await service.chat({
      companyId: COMPANY_ID,
      userId: USER_ID,
      message: 'كم عدد المنتجات الموجودة؟',
      history: [],
    });

    expect(result.reply).toContain('4');
    expect(result.reply).toContain('148');
    expect(result.reply).not.toMatch(/[\u4e00-\u9fa5]/);
  });
});

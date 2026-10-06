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
const { parseInvoiceText } = require('../invoice.parser');
const service = require('../ai.service');

const COMPANY_ID = '11111111-1111-1111-1111-111111111111';
const USER_ID = '22222222-2222-2222-2222-222222222222';

describe('Invoice OCR & Parsing Pipeline', () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    query.mockReset();
    mockCreate.mockReset();
    global.fetch = jest.fn();
  });

  afterAll(() => {
    global.fetch = originalFetch;
  });

  describe('Model Name Normalization & Availability', () => {
    test('normalizes implicit :latest tag correctly', () => {
      expect(service.normalizeOllamaModelName('glm-ocr')).toBe('glm-ocr');
      expect(service.normalizeOllamaModelName('glm-ocr:latest')).toBe('glm-ocr');
      expect(service.normalizeOllamaModelName('qwen2.5vl')).toBe('qwen2.5vl');
      expect(service.normalizeOllamaModelName('qwen2.5vl:latest')).toBe('qwen2.5vl');
    });

    test('preserves explicit version and size tags without collapsing them', () => {
      expect(service.normalizeOllamaModelName('qwen2.5vl:7b')).toBe('qwen2.5vl:7b');
      expect(service.normalizeOllamaModelName('qwen2.5vl:3b')).toBe('qwen2.5vl:3b');
      expect(service.normalizeOllamaModelName('qwen2.5:7b')).toBe('qwen2.5:7b');
    });

    test('detects equivalent model names with or without :latest', () => {
      const available = ['glm-ocr:latest', 'qwen2.5vl:7b', 'qwen2.5:7b'];

      expect(service.isModelAvailable('glm-ocr', available)).toBe(true);
      expect(service.isModelAvailable('glm-ocr:latest', available)).toBe(true);
      expect(service.isModelAvailable('qwen2.5vl:7b', available)).toBe(true);
      expect(service.isModelAvailable('qwen2.5:7b', available)).toBe(true);

      // Distinct tags must NOT match
      expect(service.isModelAvailable('qwen2.5vl:latest', available)).toBe(false);
      expect(service.isModelAvailable('qwen2.5vl:3b', available)).toBe(false);
      expect(service.isModelAvailable('nonexistent-model', available)).toBe(false);
    });
  });

  describe('Ollama Preflight & Fast Failure', () => {
    test('pingOllama succeeds when all required models are available', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [
            { name: 'glm-ocr:latest' },
            { name: 'qwen2.5vl:7b' },
            { name: 'qwen2.5:7b' },
          ],
        }),
      });

      const res = await service.pingOllama(['glm-ocr', 'qwen2.5vl:7b']);
      expect(res.availableModels).toContain('glm-ocr:latest');
    });

    test('pingOllama throws 503 AI_NOT_CONFIGURED when Ollama is unreachable', async () => {
      global.fetch.mockRejectedValueOnce(new Error('fetch failed: connection refused'));

      await expect(service.pingOllama(['glm-ocr:latest'])).rejects.toMatchObject({
        statusCode: 503,
        code: 'AI_NOT_CONFIGURED',
      });
    });

    test('pingOllama throws 503 AI_NOT_CONFIGURED when a required model is missing', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'qwen2.5:7b' }],
        }),
      });

      await expect(service.pingOllama(['glm-ocr:latest', 'qwen2.5vl:7b'])).rejects.toMatchObject({
        statusCode: 503,
        code: 'AI_NOT_CONFIGURED',
        message: expect.stringContaining('Required AI model(s) not found on the Ollama server'),
      });
    });
  });

  describe('Health Check Audit', () => {
    test('reports ok when all configured models are available', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [
            { name: 'glm-ocr:latest' },
            { name: 'qwen2.5vl:7b' },
            { name: 'qwen2.5:7b' },
          ],
        }),
      });

      const health = await service.checkHealth();
      expect(health.status).toBe('ok');
      expect(health.missingModels).toEqual([]);
      expect(health.availableModels).toHaveLength(3);
    });

    test('reports degraded when a model is missing', async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'qwen2.5:7b' }],
        }),
      });

      const health = await service.checkHealth();
      expect(health.status).toBe('degraded');
      expect(health.missingModels.length).toBeGreaterThan(0);
    });

    test('reports offline when Ollama is unreachable', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Connection refused'));

      const health = await service.checkHealth();
      expect(health.status).toBe('offline');
      expect(health.error).toBeDefined();
    });
  });

  describe('parseInvoiceText (Deterministic Rule-Based Parser)', () => {
    test('extracts supplier, date, and tabular items from French Algerian invoice text', () => {
      const ocrText = `
        ETS BOUALEM & FRERES
        Grossiste Alimentaire Alger
        Date: 14/03/2026
        Facture N° 2026-0891
        Designation   Qte   P.U     Montant
        Lait Candia 1L   24   125.00   3000.00
        Farine Sim 10kg  10   450.00   4500.00
        Huile Elio 5L    6    620.00   3720.00
        Total HT: 11220.00
        TVA 19%: 2131.80
        Total TTC: 13351.80
        Merci de votre visite
      `;

      const result = parseInvoiceText(ocrText);

      expect(result.supplier).toBe('ETS BOUALEM & FRERES');
      expect(result.date).toBe('2026-03-14');
      expect(result.items.length).toBe(3);

      expect(result.items[0]).toEqual({
        name: 'Lait Candia 1L',
        quantity: 24,
        unitPrice: 125.0,
      });

      expect(result.items[1]).toEqual({
        name: 'Farine Sim 10kg',
        quantity: 10,
        unitPrice: 450.0,
      });

      expect(result.items[2]).toEqual({
        name: 'Huile Elio 5L',
        quantity: 6,
        unitPrice: 620.0,
      });
    });

    test('extracts supplier, date, and items from Arabic invoice text', () => {
      const ocrText = `
        مؤسسة الأمل للمواد الغذائية
        التاريخ: 2026-02-18
        فاتورة رقم: 542
        السلعة   الكمية   السعر
        سكر أبيض 1كغ   50   95.00
        قهوة فاميكو 250غ  30  220.00
        المجموع الكلي: 11350.00
        شكراً لتعاملكم معنا
      `;

      const result = parseInvoiceText(ocrText);

      expect(result.supplier).toBe('مؤسسة الأمل للمواد الغذائية');
      expect(result.date).toBe('2026-02-18');
      expect(result.items.length).toBe(2);
      expect(result.items[0]).toEqual({
        name: 'سكر أبيض 1كغ',
        quantity: 50,
        unitPrice: 95.0,
      });
      expect(result.items[1]).toEqual({
        name: 'قهوة فاميكو 250غ',
        quantity: 30,
        unitPrice: 220.0,
      });
    });

    test('handles empty or noisy text gracefully without throwing or inventing items', () => {
      expect(parseInvoiceText('')).toEqual({ items: [], supplier: null, date: null, total: null });
      expect(parseInvoiceText(null)).toEqual({ items: [], supplier: null, date: null, total: null });
      const noisyResult = parseInvoiceText('Random unformatted text without any numbers or products');
      expect(noisyResult.items).toEqual([]);
      expect(noisyResult.date).toBeNull();
      expect(noisyResult.total).toBeNull();
    });
  });

  describe('scanInvoice Integration (GLM-OCR + Vision fallback)', () => {
    test('extracts items using GLM-OCR and deterministic parser as primary engine', async () => {
      // 1. checkRateLimit
      query.mockResolvedValueOnce({ rows: [{ count: 0 }] });

      // 2. Preflight fetch
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'glm-ocr:latest' }, { name: 'qwen2.5vl:7b' }],
        }),
      });

      // 3. GLM-OCR generate fetch
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          response: 'ETS BOUALEM FRERES\nDate: 2026-03-14\nLait Candia 1L 24 125.00 3000.00\nFarine Sim 10kg 10 450.00 4500.00\nTotal TTC: 7500.00 DA',
        }),
      });

      // 4. Mock logAi insert
      query.mockResolvedValueOnce({ rows: [{ id: 'mock-ocr-log-id' }] });

      const result = await service.scanInvoice({
        companyId: COMPANY_ID,
        userId: USER_ID,
        imageBase64: 'fake-base64-data',
        mimeType: 'image/jpeg',
      });

      expect(result.logId).toBe('mock-ocr-log-id');
      expect(result.supplier).toBe('ETS BOUALEM FRERES');
      expect(result.date).toBe('2026-03-14');
      expect(result.items).toHaveLength(2);
      expect(result.items[0]).toEqual({ name: 'Lait Candia 1L', quantity: 24, unitPrice: 125 });
      expect(result.items[1]).toEqual({ name: 'Farine Sim 10kg', quantity: 10, unitPrice: 450 });
    });

    test('falls back to Qwen2.5-VL vision when GLM-OCR fails or returns empty text', async () => {
      // 1. checkRateLimit
      query.mockResolvedValueOnce({ rows: [{ count: 0 }] });

      // 2. Preflight fetch
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'glm-ocr:latest' }, { name: 'qwen2.5vl:7b' }],
        }),
      });

      // 3. GLM-OCR fails / returns empty
      global.fetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        text: async () => 'Internal OCR error',
      });

      // 4. Qwen2.5-VL vision fallback returns structured JSON
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          response: JSON.stringify({
            supplier: 'EURL MODIRI',
            date: '2026-01-01',
            items: [
              { name: 'Lait 1L', quantity: 10, unitPrice: 110.0 },
              { name: 'Fromage 500g', quantity: 5, unitPrice: 240.0 },
            ],
          }),
        }),
      });

      // 5. Mock logAi insert
      query.mockResolvedValueOnce({ rows: [{ id: 'mock-vision-log-id' }] });

      const result = await service.scanInvoice({
        companyId: COMPANY_ID,
        userId: USER_ID,
        imageBase64: 'fake-base64-data',
        mimeType: 'image/png',
      });

      expect(result.logId).toBe('mock-vision-log-id');
      expect(result.supplier).toBe('EURL MODIRI');
      expect(result.items).toHaveLength(2);
      expect(result.items[0]).toEqual({ name: 'Lait 1L', quantity: 10, unitPrice: 110 });
      expect(result.items[1]).toEqual({ name: 'Fromage 500g', quantity: 5, unitPrice: 240 });
    });

    test('throws 503 AI_NOT_CONFIGURED during preflight if Ollama is down', async () => {
      query.mockResolvedValueOnce({ rows: [{ count: 0 }] });
      global.fetch.mockRejectedValueOnce(new Error('ECONNREFUSED'));

      await expect(
        service.scanInvoice({
          companyId: COMPANY_ID,
          userId: USER_ID,
          imageBase64: 'fake-base64',
          mimeType: 'image/jpeg',
        }),
      ).rejects.toMatchObject({
        statusCode: 503,
        code: 'AI_NOT_CONFIGURED',
      });
    });

    test('throws AI_REQUEST_FAILED when both OCR and vision fail to extract items', async () => {
      query.mockResolvedValueOnce({ rows: [{ count: 0 }] });

      // Preflight ok
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'glm-ocr:latest' }, { name: 'qwen2.5vl:7b' }],
        }),
      });

      // GLM-OCR returns empty
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ response: '' }),
      });

      // Vision fallback returns empty items
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ response: JSON.stringify({ items: [] }) }),
      });

      await expect(
        service.scanInvoice({
          companyId: COMPANY_ID,
          userId: USER_ID,
          imageBase64: 'fake-base64',
          mimeType: 'image/jpeg',
        }),
      ).rejects.toMatchObject({
        statusCode: 500,
        code: 'AI_REQUEST_FAILED',
        message: expect.stringContaining('Unable to extract invoice items'),
      });
    });
  });

  describe('extractOcr Service', () => {
    test('extracts raw OCR text lines and logs interaction', async () => {
      query.mockResolvedValueOnce({ rows: [{ count: 0 }] });

      // Preflight
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'glm-ocr:latest' }],
        }),
      });

      // GLM-OCR response
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          response: 'Ligne 1: Facture\nLigne 2: Fournisseur X\nLigne 3: Total 5000 DA',
        }),
      });

      // Mock logAi
      query.mockResolvedValueOnce({ rows: [{ id: 'ocr-log-123' }] });

      const result = await service.extractOcr({
        companyId: COMPANY_ID,
        userId: USER_ID,
        imageBase64: 'fake-image-data',
        mimeType: 'image/jpeg',
      });

      expect(result.logId).toBe('ocr-log-123');
      expect(result.lineCount).toBe(3);
      expect(result.lines).toEqual([
        'Ligne 1: Facture',
        'Ligne 2: Fournisseur X',
        'Ligne 3: Total 5000 DA',
      ]);
      expect(result.text).toContain('Fournisseur X');
    });
  });

  describe('Enhanced Deterministic Invoice Parser (Real-world Cases)', () => {
    test('extracts exactly 7 real items and total from supermarket invoice with dollar signs', () => {
      const realInvoiceText = `SUPERMARKET
Lorem ipsum 258
City Index - D2025
Tel.: +456-468-987-02

Cashier: #3
Manager: Eric Steer

Name Qty Price
Lorem ipsum 1 $9.20
Lorem ipsum dolor sit 1 $19.20
Lorem ipsum dolor sit amet 1 $15.00
Lorem ipsum 1 $15.00
Lorem ipsum 1 $15.00
Lorem ipsum dolor sit 1 $15.00
Lorem ipsum 1 $19.20

Sub Total $107.60
CASH $200.00
CHANGE $92.40

THANK YOU!
Glad to see you again!

modif.al`;

      const result = parseInvoiceText(realInvoiceText);

      expect(result.supplier).toBe('SUPERMARKET');
      expect(result.total).toBe(107.6);
      expect(result.items.length).toBe(7);

      expect(result.items).toEqual([
        { name: 'Lorem ipsum', quantity: 1, unitPrice: 9.2 },
        { name: 'Lorem ipsum dolor sit', quantity: 1, unitPrice: 19.2 },
        { name: 'Lorem ipsum dolor sit amet', quantity: 1, unitPrice: 15.0 },
        { name: 'Lorem ipsum', quantity: 1, unitPrice: 15.0 },
        { name: 'Lorem ipsum', quantity: 1, unitPrice: 15.0 },
        { name: 'Lorem ipsum dolor sit', quantity: 1, unitPrice: 15.0 },
        { name: 'Lorem ipsum', quantity: 1, unitPrice: 19.2 },
      ]);
    });

    test('correctly ignores metadata like cashier, change, subtotal, and tax ID from items list', () => {
      const text = `STORE ALGER
NIF: 000192837465000
Tel: 021234567
Cashier: Mohammed
Name Qty Price
Biscuit Bimo 5 45.00 DA
Chocolat Maxon 2 120.00 DA
Sub Total 465.00 DA
CASH 500.00 DA
CHANGE 35.00 DA`;

      const result = parseInvoiceText(text);
      expect(result.items.length).toBe(2);
      expect(result.items[0]).toEqual({ name: 'Biscuit Bimo', quantity: 5, unitPrice: 45 });
      expect(result.items[1]).toEqual({ name: 'Chocolat Maxon', quantity: 2, unitPrice: 120 });
      expect(result.total).toBe(465);
    });

    test('extracts total when currency symbol precedes number ($107.60, €50.00, etc.)', () => {
      const text = `GROCERY
Date: 2026-09-20
Pain 2 $3.50
Total: $7.00`;

      const result = parseInvoiceText(text);
      expect(result.total).toBe(7.0);
      expect(result.items).toEqual([{ name: 'Pain', quantity: 2, unitPrice: 3.5 }]);
    });
  });
});


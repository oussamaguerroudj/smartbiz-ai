const service = require('../ai.service');
const env = require('../../../config/env');
const { query } = require('../../../config/db');

jest.mock('../../../config/db', () => ({
  query: jest.fn(),
}));

describe('Ollama Cloud Migration & Zero-PC Dependency', () => {
  const originalEnv = { ...env };
  const originalFetch = global.fetch;

  beforeEach(() => {
    query.mockReset();
    global.fetch = jest.fn();
  });

  afterAll(() => {
    global.fetch = originalFetch;
    Object.assign(env, originalEnv);
  });

  describe('Cloud Base URL Validation (isAllowedAiBaseUrl)', () => {
    test('permits official Ollama Cloud URLs on standard HTTPS port 443', () => {
      const allowed = [
        'https://ollama.com/v1',
        'https://ollama.com/api',
        'https://api.ollama.com/v1',
        'https://ollama.com:443/v1',
      ];

      for (const url of allowed) {
        expect(() => {
          service.updateRuntimeAiConfig({ baseUrl: url });
        }).not.toThrow();
        expect(service.getAiConfig().baseUrl).toBe(url);
      }
    });

    test('continues to permit local development inference endpoints on port 11434', () => {
      expect(() => {
        service.updateRuntimeAiConfig({ baseUrl: 'http://localhost:11434/v1' });
      }).not.toThrow();
      expect(service.getAiConfig().baseUrl).toBe('http://localhost:11434/v1');
    });

    test('rejects SSRF metadata and disallowed hosts', () => {
      const disallowed = [
        'http://169.254.169.254/v1',
        'http://metadata.google.internal/v1',
        'http://0.0.0.0:11434/v1',
        'http://evil-attacker.com/v1',
      ];

      for (const url of disallowed) {
        expect(() => {
          service.updateRuntimeAiConfig({ baseUrl: url });
        }).toThrow(expect.objectContaining({ statusCode: 400, code: 'INVALID_AI_BASE_URL' }));
      }
    });
  });

  describe('Production Cloud Isolation (No Localhost Fallback)', () => {
    test('fails fast with AI_NOT_CONFIGURED in production if baseUrl points to localhost', async () => {
      const previousNodeEnv = env.nodeEnv;
      try {
        env.nodeEnv = 'production';
        service.updateRuntimeAiConfig({ baseUrl: 'http://localhost:11434/v1' });

        await expect(service.pingOllama(['glm-5.3-flash:cloud'])).rejects.toMatchObject({
          statusCode: 503,
          code: 'AI_NOT_CONFIGURED',
          message: expect.stringContaining('AI Cloud service is not configured in production'),
        });
      } finally {
        env.nodeEnv = previousNodeEnv;
        service.updateRuntimeAiConfig({ baseUrl: 'http://localhost:11434/v1' });
      }
    });

    test('fails fast with AI_NOT_CONFIGURED in production if cloud API key is missing', async () => {
      const previousNodeEnv = env.nodeEnv;
      const previousKey = env.ai.apiKey;
      try {
        env.nodeEnv = 'production';
        env.ai.apiKey = null;
        service.updateRuntimeAiConfig({
          baseUrl: 'https://ollama.com/v1',
        });

        await expect(service.pingOllama(['glm-5.3-flash:cloud'])).rejects.toMatchObject({
          statusCode: 503,
          code: 'AI_NOT_CONFIGURED',
          message: expect.stringContaining('Localhost fallback is disabled in production'),
        });
      } finally {
        env.nodeEnv = previousNodeEnv;
        env.ai.apiKey = previousKey;
        service.updateRuntimeAiConfig({ baseUrl: 'http://localhost:11434/v1' });
      }
    });
  });

  describe('Cloud Authentication & Bearer Header Transmission', () => {
    test('sends Authorization Bearer header to Ollama Cloud in pingOllama', async () => {
      const previousKey = env.ai.apiKey;
      try {
        env.ai.apiKey = 'test_cloud_token_12345';
        service.updateRuntimeAiConfig({ baseUrl: 'https://ollama.com/v1' });

        global.fetch.mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            models: [{ name: 'gemma4:31b' }],
          }),
        });

        await service.pingOllama(['glm-5.3-flash:cloud']);

        expect(global.fetch).toHaveBeenCalledWith(
          'https://ollama.com/api/tags',
          expect.objectContaining({
            headers: {
              Authorization: 'Bearer test_cloud_token_12345',
            },
          }),
        );
      } finally {
        env.ai.apiKey = previousKey;
        service.updateRuntimeAiConfig({ baseUrl: 'http://localhost:11434/v1' });
      }
    });

    test('sends Authorization Bearer header in runOcr to Ollama Cloud with glm-5.3-flash:cloud', async () => {
      const previousKey = env.ai.apiKey;
      try {
        env.ai.apiKey = 'test_cloud_token_12345';
        service.updateRuntimeAiConfig({
          baseUrl: 'https://ollama.com/v1',
          ocrModel: 'glm-5.3-flash:cloud',
        });

        global.fetch.mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            response: 'Facture N 123\nTotal: 1500 DA',
          }),
        });

        const text = await service.runOcr('fake-base64');
        expect(text).toContain('Facture N 123');

        expect(global.fetch).toHaveBeenCalledWith(
          'https://ollama.com/api/generate',
          expect.objectContaining({
            method: 'POST',
            headers: expect.objectContaining({
              Authorization: 'Bearer test_cloud_token_12345',
              'Content-Type': 'application/json',
            }),
            body: expect.stringContaining('"model":"glm-5.3-flash:cloud"'),
          }),
        );
      } finally {
        env.ai.apiKey = previousKey;
        service.updateRuntimeAiConfig({ baseUrl: 'http://localhost:11434/v1' });
      }
    });
  });

  describe('Invoice Extraction with Hosted Cloud Model (Mocked)', () => {
    beforeEach(() => {
      service.updateRuntimeAiConfig({
        baseUrl: 'https://ollama.com/v1',
        ocrModel: 'gemma4:31b',
        visionModel: 'gemma4:31b',
      });
    });

    afterEach(() => {
      service.updateRuntimeAiConfig({
        baseUrl: 'http://localhost:11434/v1',
      });
    });

    test('extracts valid invoice items via cloud OCR + deterministic parser', async () => {
      const COMPANY_ID = '11111111-1111-1111-1111-111111111111';
      const USER_ID = '22222222-2222-2222-2222-222222222222';

      query
        .mockResolvedValueOnce({ rows: [{ count: 0 }] }) // checkRateLimit
        .mockResolvedValueOnce({ rows: [{ id: 'ai-log-101' }] }); // logAi

      // pingOllama
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'glm-5.3-flash:cloud' }],
        }),
      });

      // OCR generate call
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          response: 'FACTURE\nFOURNISSEUR: SARL ALGERIE\nDATE: 2026-10-09\n1x Huile d\'olive 1000 DA\n2x Couscous 500 DA\nTOTAL: 2000 DA',
        }),
      });

      const result = await service.scanInvoice({
        companyId: COMPANY_ID,
        userId: USER_ID,
        imageBase64: 'fake-base64-image',
        mimeType: 'image/jpeg',
      });

      expect(result.items.length).toBeGreaterThan(0);
      expect(result.supplier).toContain('SARL ALGERIE');
      expect(result.total).toBe(2000);
      expect(result.logId).toBe('ai-log-101');
    });

    test('recovers via cloud vision fallback when OCR text is empty', async () => {
      const COMPANY_ID = '11111111-1111-1111-1111-111111111111';
      const USER_ID = '22222222-2222-2222-2222-222222222222';

      query
        .mockResolvedValueOnce({ rows: [{ count: 0 }] }) // checkRateLimit
        .mockResolvedValueOnce({ rows: [{ id: 'ai-log-102' }] }); // logAi

      // pingOllama
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          models: [{ name: 'gemma4:31b' }],
        }),
      });

      // OCR returns empty
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ response: '' }),
      });

      // Vision fallback returns structured JSON
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          response: JSON.stringify({
            items: [{ name: 'Farine 5kg', quantity: 2, unitPrice: 350 }],
            supplier: 'Moulins du Centre',
            date: '2026-10-09',
            total: 700,
          }),
        }),
      });

      const result = await service.scanInvoice({
        companyId: COMPANY_ID,
        userId: USER_ID,
        imageBase64: 'fake-base64-image',
        mimeType: 'image/jpeg',
      });

      expect(result.items).toEqual([
        { name: 'Farine 5kg', quantity: 2, unitPrice: 350 },
      ]);
      expect(result.supplier).toBe('Moulins du Centre');
      expect(result.total).toBe(700);
    });

    test('throws AI_REQUEST_FAILED when both OCR and vision fallback fail to extract items', async () => {
      const COMPANY_ID = '11111111-1111-1111-1111-111111111111';
      const USER_ID = '22222222-2222-2222-2222-222222222222';

      query.mockResolvedValueOnce({ rows: [{ count: 0 }] });

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ models: [{ name: 'gemma4:31b' }] }),
      });
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ response: '' }),
      });
      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ response: '{"items": []}' }),
      });

      await expect(
        service.scanInvoice({
          companyId: COMPANY_ID,
          userId: USER_ID,
          imageBase64: 'fake-base64-image',
          mimeType: 'image/jpeg',
        }),
      ).rejects.toMatchObject({
        statusCode: 500,
        code: 'AI_REQUEST_FAILED',
        message: expect.stringContaining('Unable to extract invoice items'),
      });
    });
  });

  describe('Secret Safety & Log Isolation', () => {
    test('never exposes OLLAMA_API_KEY in checkHealth response', async () => {
      const previousKey = env.ai.apiKey;
      try {
        env.ai.apiKey = 'SUPER_SECRET_OLLAMA_TOKEN_999';
        service.updateRuntimeAiConfig({ baseUrl: 'https://ollama.com/v1' });

        global.fetch.mockResolvedValueOnce({
          ok: true,
          json: async () => ({ models: [{ name: 'gemma4:31b' }] }),
        });

        const health = await service.checkHealth();
        const json = JSON.stringify(health);
        expect(json).not.toContain('SUPER_SECRET_OLLAMA_TOKEN_999');
      } finally {
        env.ai.apiKey = previousKey;
        service.updateRuntimeAiConfig({ baseUrl: 'http://localhost:11434/v1' });
      }
    });
  });
});

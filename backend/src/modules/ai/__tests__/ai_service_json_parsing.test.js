jest.mock('../../../config/db', () => ({ query: jest.fn() }));
jest.mock('openai', () => jest.fn());

const { parseJsonLoose } = require('../ai.service');

describe('parseJsonLoose (Ch. 21/28 — malformed model output)', () => {
  test('parses clean JSON directly', () => {
    expect(parseJsonLoose('{"items": []}')).toEqual({ items: [] });
  });

  test('extracts JSON embedded in extra prose (open-source models are less strict than OpenAI about response_format)', () => {
    const raw = 'Sure! Here is the result:\n{"items": [{"name": "Milk", "quantity": 2, "unitPrice": 120}]}\nLet me know if you need anything else.';
    const parsed = parseJsonLoose(raw);
    expect(parsed.items).toHaveLength(1);
    expect(parsed.items[0].name).toBe('Milk');
  });

  test('returns null (not a throw) for genuinely unparseable text — Ch. 21 "incorrect OCR" / model hallucination case', () => {
    expect(parseJsonLoose('I cannot read this invoice, sorry.')).toBeNull();
  });

  test('returns null for empty string', () => {
    expect(parseJsonLoose('')).toBeNull();
  });

  test('handles a JSON object containing nested braces correctly', () => {
    const raw = '{"insights": [{"title": "Low stock", "detail": "3 items {urgent}", "severity": "alert"}]}';
    const parsed = parseJsonLoose(raw);
    expect(parsed.insights[0].severity).toBe('alert');
  });
});

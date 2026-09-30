const {
  detectPreIntent,
  extractNumbersFromText,
  extractNumbersFromToolResults,
  formatDeterministicResponse,
  validateAndGroundResponse,
} = require('../grounding.validator');

describe('grounding.validator — intent detection, fact auditing, and anti-hallucination', () => {
  describe('detectPreIntent', () => {
    test('detects in-stock products listing intent in Arabic, French, and English', () => {
      const ar = detectPreIntent('ما هي المنتجات الموجودة في المخزون؟');
      expect(ar).toEqual({ toolName: 'get_products', args: { filter: 'in_stock', limit: 20 } });

      const fr = detectPreIntent('Quels sont les produits en stock ?');
      expect(fr).toEqual({ toolName: 'get_products', args: { filter: 'in_stock', limit: 20 } });

      const en = detectPreIntent('What products are currently in stock?');
      expect(en).toEqual({ toolName: 'get_products', args: { filter: 'in_stock', limit: 20 } });
    });

    test('detects inventory summary / total product count intent', () => {
      const ar = detectPreIntent('كم عدد المنتجات الموجودة؟');
      expect(ar).toEqual({ toolName: 'get_inventory_summary', args: {} });

      const fr = detectPreIntent('combien de produits avons-nous ?');
      expect(fr).toEqual({ toolName: 'get_inventory_summary', args: {} });

      const en = detectPreIntent('how many products do we have?');
      expect(en).toEqual({ toolName: 'get_inventory_summary', args: {} });
    });

    test('detects specific product stock inquiry in Arabic, French, and English', () => {
      const arMilk = detectPreIntent('كم لدينا من الحليب؟');
      expect(arMilk.toolName).toBe('get_product_stock');
      expect(arMilk.args.productName).toContain('الحليب');

      const arCoca = detectPreIntent('هل منتج Coca-Cola متوفر في المخزون؟');
      expect(arCoca.toolName).toBe('get_product_stock');
      expect(arCoca.args.productName).toContain('Coca-Cola');

      const frMilk = detectPreIntent('Combien avons-nous de lait ?');
      expect(frMilk.toolName).toBe('get_product_stock');
      expect(frMilk.args.productName).toContain('lait');

      const enMilk = detectPreIntent('How many units of milk do we have?');
      expect(enMilk.toolName).toBe('get_product_stock');
      expect(enMilk.args.productName).toContain('milk');
    });

    test('detects sales and revenue intents', () => {
      const arSales = detectPreIntent('كم حققنا هذا الشهر؟');
      expect(arSales).toEqual({ toolName: 'get_sales_summary', args: { period: 'this_month' } });

      const frSales = detectPreIntent('Quel est le chiffre d\'affaires aujourd\'hui ?');
      expect(frSales).toEqual({ toolName: 'get_sales_summary', args: { period: 'today' } });
    });
  });

  describe('extractNumbersFromToolResults & extractNumbersFromText', () => {
    test('extracts numbers from complex nested tool output', () => {
      const toolOutput = [
        {
          found: true,
          product: {
            id: '1111-2222',
            name: 'Whole Milk 1L',
            quantity: 79,
            selling_price: '180.00',
            purchase_price: 120,
          },
        },
      ];

      const numbers = extractNumbersFromToolResults(toolOutput);
      expect(numbers).toContain(79);
      expect(numbers).toContain(180);
      expect(numbers).toContain(120);
    });

    test('extracts numbers from text', () => {
      const nums = extractNumbersFromText('لديكم 79 وحدة من الحليب بسعر 180 دج');
      expect(nums).toEqual([79, 180]);
    });
  });

  describe('validateAndGroundResponse — anti-hallucination rules', () => {
    const company = { name: 'Amine Grocery', business_type: 'grocery', currency: 'دج' };
    const toolResult = {
      found: true,
      product: {
        id: '123',
        name: 'hlib',
        quantity: 79,
        selling_price: 180,
      },
    };

    test('rejects Chinese drift and returns grounded deterministic template', () => {
      const driftedReply = '你有79瓶牛奶，价格180。';
      const validated = validateAndGroundResponse({
        reply: driftedReply,
        lang: 'ar',
        company,
        collectedToolResults: [toolResult],
      });

      expect(validated).not.toMatch(/[\u4e00-\u9fa5]/); // zero Chinese
      expect(validated).toContain('79');
      expect(validated).toContain('180');
      expect(validated).toContain('hlib');
    });

    test('rejects foreign language when Arabic was asked', () => {
      const englishReply = 'You have 79 units of hlib at 180 DZD.';
      const validated = validateAndGroundResponse({
        reply: englishReply,
        lang: 'ar',
        company,
        collectedToolResults: [toolResult],
      });

      // Must be formatted in Arabic
      expect(validated).toMatch(/[\u0600-\u06FF]/);
      expect(validated).toContain('79');
      expect(validated).toContain('180');
    });

    test('rejects invented/hallucinated business numbers', () => {
      // Model invented "50" units instead of database's 79
      const hallucinatedReply = 'لديكم 50 وحدة من hlib في المخزون.';
      const validated = validateAndGroundResponse({
        reply: hallucinatedReply,
        lang: 'ar',
        company,
        collectedToolResults: [toolResult],
      });

      // Must be replaced with the database truth (79)
      expect(validated).toContain('79');
      expect(validated).not.toContain('50');
    });

    test('passes through genuine responses when numbers match database exactly', () => {
      const genuineReply = 'لديكم حالياً 79 وحدة من منتج hlib بسعر 180 دج في المخزون.';
      const validated = validateAndGroundResponse({
        reply: genuineReply,
        lang: 'ar',
        company,
        collectedToolResults: [toolResult],
      });

      expect(validated).toBe(genuineReply);
    });

    test('strictly enforces not-found message when product is absent from database', () => {
      const notFoundToolResult = {
        found: false,
        query: 'منتج_غير_موجود',
      };

      // Model hallucinated that it is available
      const hallucinatedReply = 'نعم، المنتج متوفر في المخزون ولدينا منه 10 قطع.';
      const validated = validateAndGroundResponse({
        reply: hallucinatedReply,
        lang: 'ar',
        company,
        collectedToolResults: [notFoundToolResult],
      });

      expect(validated).toContain('لم أجد أي منتج مطابق');
      expect(validated).not.toContain('10');
    });
  });

  describe('formatDeterministicResponse', () => {
    test('formats product not found in Arabic, French, and English', () => {
      const res = { found: false, query: 'test' };
      expect(formatDeterministicResponse(res, 'ar')).toContain('لم أجد أي منتج مطابق لـ "test"');
      expect(formatDeterministicResponse(res, 'fr')).toContain('Je n\'ai trouvé aucun produit correspondant à "test"');
      expect(formatDeterministicResponse(res, 'en')).toContain('I could not find any product matching "test"');
    });

    test('formats single product stock in Arabic, French, and English', () => {
      const res = {
        found: true,
        product: { name: 'Lait', quantity: 42, selling_price: 180 },
      };
      expect(formatDeterministicResponse(res, 'ar', { currency: 'دج' })).toContain('42 وحدة');
      expect(formatDeterministicResponse(res, 'fr', { currency: 'DZD' })).toContain('42 unité(s)');
      expect(formatDeterministicResponse(res, 'en', { currency: 'DZD' })).toContain('42 unit(s)');
    });
  });
});

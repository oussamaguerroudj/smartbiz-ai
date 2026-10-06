const {
  detectLanguage,
  containsChinese,
  normalizeSearchText,
  stripArabicPrefix,
  expandSearchAliases,
} = require('../language.detector');

describe('language.detector — detection, normalization, and alias expansion', () => {
  describe('detectLanguage', () => {
    test('detects Arabic questions correctly', () => {
      expect(detectLanguage('ما هي المنتجات الموجودة في المخزون؟')).toBe('ar');
      expect(detectLanguage('كم لدينا من الحليب؟')).toBe('ar');
      expect(detectLanguage('هل المنتج متوفر؟')).toBe('ar');
      expect(detectLanguage('شحال عندنا من هاد البرودوي؟')).toBe('ar');
      expect(detectLanguage('كم حققنا هذا الشهر؟')).toBe('ar');
    });

    test('detects French questions correctly', () => {
      expect(detectLanguage('Quels sont les produits en stock ?')).toBe('fr');
      expect(detectLanguage('Combien avons-nous de lait ?')).toBe('fr');
      expect(detectLanguage('Quel est le prix de ce produit ?')).toBe('fr');
      expect(detectLanguage('Quel est le chiffre d\'affaires ce mois ?')).toBe('fr');
      expect(detectLanguage('Est-ce que le produit est disponible ?')).toBe('fr');
    });

    test('detects English questions correctly', () => {
      expect(detectLanguage('What products are currently in stock?')).toBe('en');
      expect(detectLanguage('How many units of milk do we have?')).toBe('en');
      expect(detectLanguage('Is Coca-Cola in stock?')).toBe('en');
      expect(detectLanguage('What is our net profit this month?')).toBe('en');
    });
  });

  describe('containsChinese', () => {
    test('identifies Chinese characters for drift prevention', () => {
      expect(containsChinese('你有24种产品')).toBe(true);
      expect(containsChinese('库存中的产品')).toBe(true);
      expect(containsChinese('لديك 24 منتجاً في المخزون')).toBe(false);
      expect(containsChinese('You have 24 products in stock')).toBe(false);
      expect(containsChinese('Vous avez 24 produits')).toBe(false);
    });
  });

  describe('normalizeSearchText & stripArabicPrefix', () => {
    test('normalizes Alef, Ta Marbuta, diacritics, and punctuation', () => {
      expect(normalizeSearchText('حَلِيبٌ')).toBe('حليب');
      expect(normalizeSearchText('أرز')).toBe('ارز');
      expect(normalizeSearchText('إجاص')).toBe('اجاص');
      expect(normalizeSearchText('طماطم،')).toBe('طماطم');
      expect(normalizeSearchText('بقلاوة')).toBe('بقلاوه');
    });

    test('strips Arabic definite article "ال"', () => {
      expect(stripArabicPrefix('الحليب')).toBe('حليب');
      expect(stripArabicPrefix('السكر')).toBe('سكر');
      expect(stripArabicPrefix('الماء')).toBe('ماء');
      expect(stripArabicPrefix('الله')).toBe('الله'); // preserves short/special word
    });
  });

  describe('expandSearchAliases', () => {
    test('expands Algerian commercial staples across Arabic, French, and Darija', () => {
      const milkAliases = expandSearchAliases('حليب');
      expect(milkAliases).toContain('hlib');
      expect(milkAliases).toContain('lait');
      expect(milkAliases).toContain('milk');

      const milkDarija = expandSearchAliases('hlib');
      expect(milkDarija).toContain('حليب');
      expect(milkDarija).toContain('lait');

      const sodaAliases = expandSearchAliases('غازوز');
      expect(sodaAliases).toContain('gazoz');
      expect(sodaAliases).toContain('boisson');
      expect(sodaAliases).toContain('coca');

      const breadAliases = expandSearchAliases('الخبز');
      expect(breadAliases).toContain('baguette');
      expect(breadAliases).toContain('pain');
      expect(breadAliases).toContain('khobz');
    });
  });
});

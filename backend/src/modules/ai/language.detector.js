/**
 * Language detection, normalization, and localized response templates
 * for Modiri AI assistant.
 *
 * Guarantees:
 * 1. Deterministic language detection (Arabic, French, English).
 * 2. Arabic script and Algerian Darija normalization (strips 'ال', accents, diacritics, unifies alef/ta marbuta).
 * 3. Bilingual / Algerian dialect product alias mapping (e.g. حليب <-> hlib <-> lait).
 * 4. Chinese character detection for anti-drift rejection.
 * 5. Grounded fallback templates in the user's detected language.
 */

// Common Algerian commercial aliases mapping (Arabic <-> French <-> Franco-Arab / Darija)
const PRODUCT_ALIASES = [
  { canonical: 'حليب', aliases: ['حليب', 'الحليب', 'حليب كامل الدسم', 'hlib', 'lait', 'milk', 'leche'] },
  { canonical: 'خبز', aliases: ['خبز', 'الخبز', 'baguette', 'pain', 'khobz', 'bread'] },
  { canonical: 'سكر', aliases: ['سكر', 'السكر', 'sucre', 'sugar', 'sokor', 'soukar'] },
  { canonical: 'زيت', aliases: ['زيت', 'الزيت', 'huile', 'oil', 'zit'] },
  { canonical: 'ماء', aliases: ['ماء', 'الماء', 'eau', 'water', 'ma'] },
  { canonical: 'مشروب غازي', aliases: ['غازوز', 'الغازوز', 'مشروب', 'gazoz', 'gazeuse', 'boisson', 'soda', 'coca', 'pepsi'] },
  { canonical: 'طماطم', aliases: ['طماطم', 'الطماطم', 'طوماطيش', 'tomate', 'tomato', 'tomates'] },
  { canonical: 'قهوة', aliases: ['قهوة', 'القهوة', 'cafe', 'coffee', 'qahwa', 'kahwa'] },
  { canonical: 'بيض', aliases: ['بيض', 'البيض', 'oeuf', 'oeufs', 'egg', 'eggs', 'bayd'] },
  { canonical: 'فرينة', aliases: ['فرينة', 'الفرينة', 'طحين', 'farine', 'flour'] },
  { canonical: 'جبن', aliases: ['جبن', 'الجبن', 'فرماج', 'fromage', 'cheese'] },
  { canonical: 'دهان', aliases: ['دهان', 'الدهان', 'peinture', 'paint', 'dhan'] },
  { canonical: 'صابون', aliases: ['صابون', 'الصابون', 'savon', 'soap'] },
  { canonical: 'بيتزا', aliases: ['بيتزا', 'البيتزا', 'pizza', 'pizzas'] },
  { canonical: 'تاكوس', aliases: ['تاكوس', 'التاكوس', 'طاغوس', 'طاكوس', 'tacos', 'taco'] },
  { canonical: 'شاورما', aliases: ['شاورما', 'الشاورما', 'شوارما', 'chaerma', 'chawarma', 'shawarma', 'shawerma'] },
  { canonical: 'طبق', aliases: ['طبق', 'الطبق', 'أطباق', 'اطباق', 'صحن', 'plat', 'plats', 'assiette'] },
  { canonical: 'برغر', aliases: ['برغر', 'البرغر', 'برجر', 'البرجر', 'burger', 'burgers'] },
  { canonical: 'ساندويتش', aliases: ['ساندويتش', 'الساندويتش', 'سندويش', 'sandwich', 'sandwiches', 'panini'] },
  { canonical: 'بطاطا مقلية', aliases: ['فريت', 'الفريت', 'بطاطا', 'frite', 'frites', 'fries'] },
  { canonical: 'عصير', aliases: ['عصير', 'العصير', 'jus', 'juice'] },
  { canonical: 'شاي', aliases: ['شاي', 'الشاي', 'اتاي', 'تاي', 'the', 'thé', 'tea'] },
  { canonical: 'حلوى', aliases: ['حلوى', 'حلويات', 'تحلية', 'gateau', 'dessert', 'patisserie'] },
];

/**
 * Normalizes text for search indexing / comparison.
 */
function normalizeSearchText(text) {
  if (!text || typeof text !== 'string') return '';

  let norm = text.trim().toLowerCase();

  // Remove Arabic diacritics / tashkeel (ً  ٌ  ٍ  َ  ُ  ِ  ّ  ْ)
  norm = norm.replace(/[\u064B-\u0652]/g, '');

  // Normalize Alef variants (أ, إ, آ -> ا)
  norm = norm.replace(/[أإآ]/g, 'ا');

  // Normalize Ta Marbuta (ة -> ه)
  norm = norm.replace(/ة/g, 'ه');

  // Normalize Alef Maqsura (ى -> ي)
  norm = norm.replace(/ى/g, 'ي');

  // Remove common punctuation and Arabic punctuation (comma ،, semicolon ؛)
  norm = norm.replace(/[.,/#!$%^&*;:{}=\-_`~()?؟،؛]/g, ' ');

  // Collapse whitespace
  norm = norm.replace(/\s+/g, ' ').trim();

  return norm;
}

/**
 * Strips common Arabic definite article "ال" from a word if applicable.
 */
function stripArabicPrefix(word) {
  if (word === 'الله') return word;
  if (word.startsWith('ال') && word.length > 3) {
    return word.slice(2);
  }
  return word;
}

/**
 * Expands search query with known bilingual and Algerian Darija aliases.
 */
function expandSearchAliases(query) {
  const norm = normalizeSearchText(query);
  const words = norm.split(' ').map(stripArabicPrefix);
  const terms = new Set([query.trim(), norm]);

  for (const w of words) {
    if (w.length > 1) {
      terms.add(w);
    }
  }

  for (const group of PRODUCT_ALIASES) {
    const matchesGroup = group.aliases.some((alias) => {
      const normAlias = normalizeSearchText(alias);
      return norm === normAlias || words.includes(stripArabicPrefix(normAlias));
    });

    if (matchesGroup) {
      for (const a of group.aliases) {
        terms.add(a);
        terms.add(normalizeSearchText(a));
        terms.add(stripArabicPrefix(normalizeSearchText(a)));
      }
    }
  }

  return Array.from(terms).filter((t) => t.length > 0);
}

/**
 * Detects whether the user's message is primarily Arabic, French, or English.
 * Returns 'ar', 'fr', or 'en'.
 */
function detectLanguage(text) {
  if (!text || typeof text !== 'string') return 'ar';

  const trimmed = text.trim();

  // Check for Arabic characters (Unicode range 0600 - 06FF)
  const arabicCharCount = (trimmed.match(/[\u0600-\u06FF]/g) || []).length;
  const latinCharCount = (trimmed.match(/[A-Za-z]/g) || []).length;

  if (arabicCharCount > 0 && arabicCharCount >= latinCharCount * 0.3) {
    return 'ar';
  }

  // Count English matches
  const englishMatches = (trimmed.match(/\b(the|is|are|how|many|much|what|which|products|stock|inventory|price|sales|revenue|profit|customer|employee|invoice|do|we|have|in|of|did|our|available|currently)\b/gi) || []).length;

  // Count French matches
  const frenchMatches = (trimmed.match(/\b(le|la|les|un|une|des|du|de|en|est|dans|quel|quels|quelle|quelles|combien|nous|avons|produits|stock|prix|ventes|chiffre|salaire|employe|client|facture|ce|cette|pour|avec|disponible|disponibles)\b/gi) || []).length;

  if (englishMatches > 0 && englishMatches >= frenchMatches) {
    return 'en';
  }

  if (frenchMatches > 0) {
    return 'fr';
  }

  if (latinCharCount > 0) {
    return 'fr'; // default to French in Algeria when Latin characters dominate
  }

  return 'ar';
}

/**
 * Checks whether text contains Chinese characters (indicates Qwen model drift).
 */
function containsChinese(text) {
  if (!text || typeof text !== 'string') return false;
  return /[\u4e00-\u9fa5]/.test(text);
}

/**
 * Deterministic localized templates for grounded responses.
 */
const TEMPLATES = {
  ar: {
    productNotFound: (q) => `لم أجد أي منتج مطابق لـ "${q}" في بيانات المخزون المسجلة.`,
    noProductsInStock: 'لا توجد منتجات متوفرة في المخزون حالياً.',
    productsInStockSummary: (count, totalUnits) => `لديك ${count} منتج مسجل في النظام بإجمالي ${totalUnits} وحدة في المخزون.`,
    productStockSingle: (name, qty, price, currency = 'دج') => `المنتج "${name}": المتوفر في المخزون هو ${qty} وحدة${price != null ? ` (سعر البيع: ${price} ${currency})` : ''}.`,
    multipleProductMatches: (matches, currency = 'دج') => {
      const items = matches.map((m) => `• ${m.name}: ${m.quantity} وحدة${m.selling_price != null ? ` (${m.selling_price} ${currency})` : ''}`).join('\n');
      return `وجدت المنتجات التالية المطابقة لبحثك:\n${items}\nأي منها تقصد بالتحديد؟`;
    },
    noPriceRegistered: (name) => `لم أجد سعراً مسجلاً للمنتج "${name}" في بيانات النظام.`,
    databaseUnavailable: 'تعذر الوصول إلى بيانات قاعدة البيانات حالياً. يرجى المحاولة مرة أخرى.',
    revenueSummary: (periodLabel, revenue, orderCount, currency = 'دج') => `إجمالي المبيعات ${periodLabel}: ${revenue} ${currency} عبر ${orderCount} عملية بيع.`,
    profitSummary: (periodLabel, profit, revenue, expenses, currency = 'دج') => `صافي الأرباح ${periodLabel}: ${profit} ${currency} (المداخيل: ${revenue} ${currency}، المصاريف: ${expenses} ${currency}).`,
  },
  fr: {
    productNotFound: (q) => `Je n'ai trouvé aucun produit correspondant à "${q}" dans vos données de stock.`,
    noProductsInStock: 'Aucun produit disponible en stock actuellement.',
    productsInStockSummary: (count, totalUnits) => `Vous avez ${count} produits enregistrés avec un total de ${totalUnits} unités en stock.`,
    productStockSingle: (name, qty, price, currency = 'DZD') => `Produit "${name}" : le stock actuel est de ${qty} unité(s)${price != null ? ` (prix de vente : ${price} ${currency})` : ''}.`,
    multipleProductMatches: (matches, currency = 'DZD') => {
      const items = matches.map((m) => `• ${m.name} : ${m.quantity} unité(s)${m.selling_price != null ? ` (${m.selling_price} ${currency})` : ''}`).join('\n');
      return `Voici les produits correspondants trouvés :\n${items}\nLequel désirez-vous consulter ?`;
    },
    noPriceRegistered: (name) => `Aucun prix enregistré n'a été trouvé pour le produit "${name}".`,
    databaseUnavailable: 'Impossible d\'accéder aux données de la base pour le moment. Veuillez réessayer.',
    revenueSummary: (periodLabel, revenue, orderCount, currency = 'DZD') => `Chiffre d'affaires ${periodLabel} : ${revenue} ${currency} pour ${orderCount} commande(s).`,
    profitSummary: (periodLabel, profit, revenue, expenses, currency = 'DZD') => `Bénéfice net ${periodLabel} : ${profit} ${currency} (Revenus : ${revenue} ${currency}, Dépenses : ${expenses} ${currency}).`,
  },
  en: {
    productNotFound: (q) => `I could not find any product matching "${q}" in the inventory records.`,
    noProductsInStock: 'There are currently no products in stock.',
    productsInStockSummary: (count, totalUnits) => `You have ${count} products recorded with a total of ${totalUnits} units in stock.`,
    productStockSingle: (name, qty, price, currency = 'DZD') => `Product "${name}": current stock is ${qty} unit(s)${price != null ? ` (selling price: ${price} ${currency})` : ''}.`,
    multipleProductMatches: (matches, currency = 'DZD') => {
      const items = matches.map((m) => `• ${m.name}: ${m.quantity} unit(s)${m.selling_price != null ? ` (${m.selling_price} ${currency})` : ''}`).join('\n');
      return `Found the following matching products:\n${items}\nWhich one did you mean?`;
    },
    noPriceRegistered: (name) => `No registered price was found for product "${name}".`,
    databaseUnavailable: 'Database access is currently unavailable. Please try again.',
    revenueSummary: (periodLabel, revenue, orderCount, currency = 'DZD') => `Total sales ${periodLabel}: ${revenue} ${currency} across ${orderCount} order(s).`,
    profitSummary: (periodLabel, profit, revenue, expenses, currency = 'DZD') => `Net profit ${periodLabel}: ${profit} ${currency} (Revenue: ${revenue} ${currency}, Expenses: ${expenses} ${currency}).`,
  },
};

module.exports = {
  detectLanguage,
  containsChinese,
  normalizeSearchText,
  stripArabicPrefix,
  expandSearchAliases,
  TEMPLATES,
};

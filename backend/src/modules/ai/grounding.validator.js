/**
 * Deterministic grounding, intent classification, and anti-hallucination
 * validation layer for Modiri AI Assistant.
 *
 * Guarantees:
 * 1. Pre-execution detection of business intents (products, stock, price, sales, debt).
 * 2. Extraction of product queries with Arabic, French, and English patterns.
 * 3. Numerical fact extraction & validation against PostgreSQL tool results.
 * 4. Automatic rejection of hallucinations and language drift (Chinese/English/French drift).
 * 5. Deterministic fallback response generation based strictly on verified DB data.
 */

const { containsChinese, TEMPLATES } = require('./language.detector');

/**
 * Extracts candidate business intents from the user's message.
 * Returns { toolName, args } or null.
 */
function detectPreIntent(message) {
  if (!message || typeof message !== 'string') return null;
  const text = message.trim();

  // 0. Restaurant Menu / Catalog inquiry
  // "ما هي قائمة الطعام؟" / "ما هو المنيو؟" / "menu" / "mon menu" / "plats du menu" / "what is in my menu" / "عندي عناصر في المنيو"
  if (
    /قائمة\s+(?:الطعام|الوجبات|الأطباق|المنيو|الأكل|الأسعار|المنتجات|السلع)/i.test(text) ||
    /(?:ما\s+(?:هي|هو)\s+)?(?:المنيو|قائمة\s+الطعام)/i.test(text) ||
    /منيو/i.test(text) ||
    /\bmenu\b/i.test(text) ||
    /المنيو/i.test(text) ||
    /قائمة\s+الأكل/i.test(text) ||
    /(?:وش|واش|ايش|ماذا|هل)\s*(?:كاين|عندي|لدينا|موجود)?\s*(?:في\s+)?(?:المنيو|قائمة\s+الطعام)/i.test(text) ||
    /عناصر\s+(?:المنيو|القائمة)/i.test(text) ||
    /(?:quel\s+est|affiche|voir|donne(?:-moi)?|liste(?:r)?)\s+(?:le\s+|mon\s+)?menu/i.test(text) ||
    /carte\s+(?:du\s+restaurant|des\s+plats|du\s+menu)/i.test(text) ||
    /(?:what\s+(?:is|are)\s+(?:on|in)\s+(?:the|my)\s+menu|show\s+(?:me\s+)?(?:the|my)\s+menu|items?\s+in\s+menu)/i.test(text) ||
    /restaurant\s+menu/i.test(text)
  ) {
    return { toolName: 'get_restaurant_menu', args: {} };
  }

  // 1. Total products / inventory summary
  // "كم عدد المنتجات الموجودة؟" / "combien de produits avons-nous" / "how many products do we have"
  if (
    /كم\s+عدد\s+(?:المنتجات|السلع)/i.test(text) ||
    /إحصائيات\s+(?:المخزون|السلع|المنتجات)/i.test(text) ||
    /combien\s+de\s+produits/i.test(text) ||
    /how\s+many\s+products/i.test(text) ||
    /inventory\s+summary/i.test(text)
  ) {
    return { toolName: 'get_inventory_summary', args: {} };
  }

  // 2. In-stock products listing
  // "ما هي المنتجات الموجودة في المخزون؟" / "quels produits sont en stock" / "what products are in stock"
  if (
    /(?:ما\s+(?:هي|هم)\s+)?(?:المنتجات|السلع)\s+(?:الموجودة|المتوفرة)/i.test(text) ||
    /قائمة\s+(?:المنتجات|السلع)/i.test(text) ||
    /quels?\s+(?:sont\s+)?(?:les\s+)?produits\s+(?:en\s+stock|disponibles)/i.test(text) ||
    /what\s+products\s+are\s+(?:in\s+stock|available|currently\s+in\s+stock)/i.test(text)
  ) {
    return { toolName: 'get_products', args: { filter: 'in_stock', limit: 20 } };
  }

  // 3. Low stock inquiry
  // "ما هي المنتجات التي أوشكت على النفاد؟" / "produits en rupture" / "low stock products"
  if (
    /(?:منخفض|نفاد|أوشك|قريب\s+يخلاص|قليل)\s+(?:في\s+)?المخزون/i.test(text) ||
    /stock\s+(?:faible|bas|alerte)/i.test(text) ||
    /low\s+stock/i.test(text)
  ) {
    return { toolName: 'get_low_stock_products', args: {} };
  }

  // 4. Specific product stock / availability / price
  // Arabic:
  // "كم لدينا من الحليب؟" -> candidate "الحليب"
  // "كم عندنا من Coca؟" -> candidate "Coca"
  // "هل المنتج X متوفر؟" -> candidate "X"
  // "كم سعر منتج X؟" -> candidate "X"
  const arPatterns = [
    /كم\s+(?:لدينا|عندنا|بقي|فاضل|كاين|متبقي|راه\s+كاين)\s*(?:الآن|حاليا|حالياً)?\s*(?:من\s+)?(?:المنتج\s+|منتج\s+|السلعة\s+|سلعة\s+)?(.+?)(?:\s+(?:في\s+المخزون|عندنا|لدينا|الآن|حالياً))?(?:\؟|\?|$)/i,
    /هل\s+(?:المنتج\s+|منتج\s+|السلعة\s+|سلعة\s+)?(.+?)\s+(?:متوفر|موجود|كاين|متوفرة|موجودة)(?:\s+في\s+المخزون|\s+عندنا|\s+لدينا)?(?:\؟|\?|$)/i,
    /هل\s+(?:المنتج\s+|منتج\s+|السلعة\s+|سلعة\s+)?(.+?)\s+(?:في\s+المخزون)(?:\؟|\?|$)/i,
    /كم\s+سعر\s+(?:المنتج\s+|منتج\s+|السلعة\s+|سلعة\s+)?(.+?)(?:\؟|\?|$)/i,
    /سعر\s+(?:المنتج\s+|منتج\s+|السلعة\s+|سلعة\s+)?(.+?)(?:\؟|\?|$)/i,
  ];

  for (const p of arPatterns) {
    const match = text.match(p);
    if (match && match[1]) {
      const candidate = cleanCandidate(match[1]);
      if (isValidCandidate(candidate)) {
        return { toolName: 'get_product_stock', args: { productName: candidate } };
      }
    }
  }

  // French:
  // "Combien avons-nous de lait ?"
  // "Quel est le stock de Coca-Cola ?"
  // "Quel est le prix de X ?"
  // "Est-ce que le lait est disponible ?"
  const frPatterns = [
    /combien\s+(?:avons-nous|y\s+a-t-il)\s+(?:de|d')\s*(?:produit\s+)?(.+?)(?:\s+en\s+stock)?(?:\s*\?|$)/i,
    /(?:quel\s+est\s+le\s+stock\s+(?:de|du|d'|de\s+la)\s*)(.+?)(?:\s*\?|$)/i,
    /(?:quel\s+est\s+le\s+prix\s+(?:de|du|d'|de\s+la)\s*)(.+?)(?:\s*\?|$)/i,
    /est-ce\s+que\s+(?:le\s+|la\s+|l'|les\s+)?(.+?)\s+(?:est\s+disponible|en\s+stock)(?:\s*\?|$)/i,
  ];

  for (const p of frPatterns) {
    const match = text.match(p);
    if (match && match[1]) {
      const candidate = cleanCandidate(match[1]);
      if (isValidCandidate(candidate)) {
        return { toolName: 'get_product_stock', args: { productName: candidate } };
      }
    }
  }

  // English:
  // "How many units of milk do we have?"
  // "How much milk do we have?"
  // "Is Coca-Cola in stock?"
  // "What is the price of milk?"
  const enPatterns = [
    /how\s+(?:many|much)\s+(?:units\s+of\s+)?(.+?)\s+(?:do\s+we\s+have|are\s+in\s+stock|is\s+in\s+stock)(?:\?|$)/i,
    /is\s+(.+?)\s+(?:in\s+stock|available)(?:\?|$)/i,
    /what\s+is\s+the\s+price\s+of\s+(.+?)(?:\?|$)/i,
    /stock\s+of\s+(.+?)(?:\?|$)/i,
  ];

  for (const p of enPatterns) {
    const match = text.match(p);
    if (match && match[1]) {
      const candidate = cleanCandidate(match[1]);
      if (isValidCandidate(candidate)) {
        return { toolName: 'get_product_stock', args: { productName: candidate } };
      }
    }
  }

  // 5. Sales & Revenue
  // "كم حققنا هذا الشهر؟" / "كم بعنا هذا الشهر؟" / "chiffre d'affaires ce mois"
  if (
    /(?:كم\s+(?:حققنا|بعنا|مبيعات|مداخيل)|chiffre\s+d'affaires|revenue|sales)\s*(هذا\s+الشهر|اليوم|أمس|ce\s+mois|aujourd'hui|hier|this\s+month|today|yesterday)?/i.test(text)
  ) {
    let period = 'this_month';
    if (/اليوم|aujourd'hui|today/i.test(text)) period = 'today';
    else if (/أمس|hier|yesterday/i.test(text)) period = 'yesterday';
    else if (/هذا\s+العام|cette\s+année|this\s+year/i.test(text)) period = 'this_year';
    else if (/الشهر\s+الماضي|le\s+mois\s+dernier|last\s+month/i.test(text)) period = 'last_month';

    return { toolName: 'get_sales_summary', args: { period } };
  }

  // 6. Customers with debt
  // "من هم الزبائن الذين لديهم ديون؟" / "clients avec dette" / "customers with debt"
  if (
    /ديون|شكون\s+يسال|من\s+عليه\s+دين|dettes?|créances?|who\s+owes\s+money|customers?\s+with\s+debt/i.test(text)
  ) {
    return { toolName: 'get_customers_with_debt', args: { limit: 10 } };
  }

  return null;
}

function cleanCandidate(str) {
  if (!str) return '';
  let res = str
    .replace(/[؟?.,!]/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  // Strip leading words like "الآن", "حاليا", "حالياً", "من", "منتج", "المنتج", "de", "du", "d'", "of"
  res = res.replace(/^(?:الآن|حاليا|حالياً|من|منتج|المنتج|سلعة|السلعة|de|du|d'|of)\s+/i, '');
  // Strip trailing words like "الآن", "حاليا", "حالياً", "في المخزون", "متوفر", "موجود", "كاين", "متوفرة", "موجودة", "عندنا", "لدينا", "en stock", "in stock", "now"
  res = res.replace(/\s+(?:الآن|حاليا|حالياً|في\s+المخزون|متوفر|موجود|كاين|متوفرة|موجودة|عندنا|لدينا|en\s+stock|in\s+stock|now)$/i, '');

  return res.trim();
}

function isValidCandidate(candidate) {
  if (!candidate || candidate.length < 2) return false;
  // Ignore broad non-product keywords
  const broadWords = ['المنتجات', 'السلع', 'produits', 'products', 'المخزون', 'stock', 'المبيعات', 'sales'];
  return !broadWords.includes(candidate.toLowerCase());
}

/**
 * Recursively extracts all numbers from a tool result object.
 */
function extractNumbersFromToolResults(toolResults) {
  const numbers = [];

  function walk(val) {
    if (val === null || val === undefined) return;
    if (typeof val === 'number') {
      numbers.push(val);
    } else if (typeof val === 'string') {
      // Check if string represents a number (e.g. "180.00")
      if (/^-?\d+(\.\d+)?$/.test(val.trim())) {
        const num = parseFloat(val.trim());
        if (!isNaN(num)) numbers.push(num);
      }
    } else if (Array.isArray(val)) {
      for (const item of val) walk(item);
    } else if (typeof val === 'object') {
      for (const k of Object.keys(val)) {
        // Skip ID strings or date strings
        if (k === 'id' || k === 'tool_call_id' || k.endsWith('_id') || k.endsWith('At') || k.endsWith('Date')) {
          continue;
        }
        walk(val[k]);
      }
    }
  }

  for (const tr of toolResults) {
    walk(tr);
  }

  return numbers;
}

/**
 * Extracts numbers from natural language text.
 */
function extractNumbersFromText(text) {
  if (!text || typeof text !== 'string') return [];
  // Match standard numbers and Arabic-Indic numerals (٠-٩)
  const matches = text.match(/\d+(?:[.,]\d+)?/g) || [];
  const results = [];
  for (const m of matches) {
    const clean = m.replace(/,/g, '');
    const num = parseFloat(clean);
    if (!isNaN(num)) results.push(num);
  }
  return results;
}

/**
 * Formats a deterministic, safe response in the user's language using real DB tool results.
 */
function formatDeterministicResponse(toolResult, lang = 'ar', company = {}) {
  const templates = TEMPLATES[lang] || TEMPLATES.ar;
  const currency = company.currency || (lang === 'ar' ? 'دج' : 'DZD');

  if (!toolResult) {
    return templates.databaseUnavailable;
  }

  if (toolResult.error) {
    return templates.databaseUnavailable;
  }

  // Handle get_restaurant_menu
  if (toolResult && Array.isArray(toolResult.menu)) {
    const items = toolResult.menu;
    if (items.length === 0) {
      if (lang === 'fr') return "Il n'y a aucun article enregistré dans le menu pour le moment.";
      if (lang === 'en') return "There are no items currently registered in your menu.";
      return "لا توجد عناصر مسجلة في قائمة الطعام حالياً.";
    }
    const lines = items.map((i) => {
      const avail = i.isAvailable ? '' : (lang === 'fr' ? ' (non disponible)' : lang === 'en' ? ' (unavailable)' : ' (غير متوفر)');
      const cat = i.category ? ` [${i.category}]` : '';
      return `• ${i.name}${cat}: ${i.price} ${currency}${avail}`;
    }).join('\n');

    if (lang === 'fr') return `Voici les articles de votre menu (${items.length}) :\n${lines}`;
    if (lang === 'en') return `Here are the items on your menu (${items.length}):\n${lines}`;
    return `إليك عناصر قائمة الطعام (${items.length}) :\n${lines}`;
  }

  // Handle get_product_stock & search_products
  if (toolResult.found === false) {
    return templates.productNotFound(toolResult.query || '');
  }

  if (toolResult.multiple === true && Array.isArray(toolResult.matches)) {
    return templates.multipleProductMatches(toolResult.matches, currency);
  }

  if (toolResult.product) {
    const p = toolResult.product;
    if (p.type === 'menu_item') {
      const availAr = p.is_available ? 'متوفر حالياً' : 'غير متوفر حالياً';
      const availFr = p.is_available ? 'actuellement disponible' : 'actuellement non disponible';
      const availEn = p.is_available ? 'currently available' : 'currently unavailable';
      if (lang === 'fr') return `L'article "${p.name}" est ${availFr} au prix de ${p.selling_price} ${currency}.`;
      if (lang === 'en') return `The item "${p.name}" is ${availEn} at ${p.selling_price} ${currency}.`;
      return `الطبق "${p.name}" ${availAr} بسعر ${p.selling_price} ${currency}.`;
    }
    return templates.productStockSingle(p.name, p.quantity, p.selling_price, currency);
  }

  // Handle get_products
  if (Array.isArray(toolResult.products)) {
    if (toolResult.products.length === 0) {
      return templates.noProductsInStock;
    }
    const isRestaurant = toolResult.products.some((p) => p.type === 'menu_item');
    const lines = toolResult.products.slice(0, 10).map((p) => {
      if (p.type === 'menu_item') {
        const avail = p.is_available ? '' : (lang === 'fr' ? ' (non disponible)' : lang === 'en' ? ' (unavailable)' : ' (غير متوفر)');
        return `• ${p.name}: ${p.selling_price} ${currency}${avail}`;
      }
      const pricePart = p.selling_price != null ? ` (${p.selling_price} ${currency})` : '';
      return `• ${p.name}: ${p.quantity} وحدة${pricePart}`;
    }).join('\n');

    if (isRestaurant) {
      if (lang === 'fr') return `Articles de menu disponibles (${toolResult.totalCount || toolResult.products.length}) :\n${lines}`;
      if (lang === 'en') return `Available menu items (${toolResult.totalCount || toolResult.products.length}):\n${lines}`;
      return `عناصر قائمة الطعام المتوفرة (${toolResult.totalCount || toolResult.products.length} عنصر):\n${lines}`;
    }

    if (lang === 'ar') {
      return `المنتجات المتوفرة في المخزون (${toolResult.totalCount || toolResult.products.length} منتج):\n${lines}`;
    } else if (lang === 'fr') {
      return `Produits disponibles en stock (${toolResult.totalCount || toolResult.products.length} produits) :\n${lines}`;
    }
    return `Products available in stock (${toolResult.totalCount || toolResult.products.length} products):\n${lines}`;
  }

  // Handle get_inventory_summary
  if (toolResult.totalProducts !== undefined && toolResult.totalUnits !== undefined) {
    return templates.productsInStockSummary(toolResult.totalProducts, toolResult.totalUnits);
  }

  // Handle get_sales_summary
  if (toolResult.revenue !== undefined && toolResult.orderCount !== undefined) {
    return templates.revenueSummary(toolResult.period, toolResult.revenue, toolResult.orderCount, currency);
  }

  // Handle calculate_profit
  if (toolResult.profit !== undefined) {
    return templates.profitSummary(toolResult.period, toolResult.profit, toolResult.revenue, toolResult.expenses, currency);
  }

  // Handle get_customers_with_debt
  if (Array.isArray(toolResult.customersWithDebt)) {
    if (toolResult.customersWithDebt.length === 0) {
      return lang === 'ar' ? 'لا توجد ديون مستحقة على الزبائن حالياً.' : 'Aucun client n\'a de dette actuellement.';
    }
    const lines = toolResult.customersWithDebt.map((c) => `• ${c.name}: ${c.balance_due} ${currency}`).join('\n');
    return lang === 'ar' ? `قائمة الزبائن المدينين:\n${lines}` : `Clients avec solde dû :\n${lines}`;
  }

  return templates.databaseUnavailable;
}

/**
 * Validates Qwen's response against ground truth data and language constraints.
 */
function validateAndGroundResponse({ reply, lang = 'ar', company = {}, collectedToolResults = [] }) {
  const currentYear = new Date().getFullYear();

  // 1. Language constraint: Strictly reject Chinese characters
  if (containsChinese(reply)) {
    if (collectedToolResults.length > 0) {
      return formatDeterministicResponse(collectedToolResults[0], lang, company);
    }
    return lang === 'ar'
      ? 'عذراً، يرجى إعادة طرح السؤال.'
      : 'Désolé, veuillez reformuler votre question.';
  }

  // 2. Language constraint: If Arabic was requested, response MUST contain Arabic script
  if (lang === 'ar') {
    const hasArabic = /[\u0600-\u06FF]/.test(reply);
    if (!hasArabic && collectedToolResults.length > 0) {
      return formatDeterministicResponse(collectedToolResults[0], lang, company);
    }
  }

  // 3. Factual source-of-truth check for Product Not Found
  for (const tr of collectedToolResults) {
    if (tr && tr.found === false && tr.query) {
      // If DB says product was NOT found, ensure the model didn't hallucinate that it exists
      const claimsAvailable = /(?:متوفر|موجود|en\s+stock|available|لدينا\s+\d+|nous\s+avons\s+\d+)/i.test(reply);
      const admitsNotFound = /(?:لم\s+أجد|غير\s+متوفر|لا\s+يوجد|pas\s+trouvé|non\s+disponible|could\s+not\s+find|not\s+found)/i.test(reply);

      if (claimsAvailable && !admitsNotFound) {
        return formatDeterministicResponse(tr, lang, company);
      }
    }
  }

  // 4. Numerical hallucination check
  if (collectedToolResults.length > 0) {
    const verifiedNumbers = extractNumbersFromToolResults(collectedToolResults);
    const replyNumbers = extractNumbersFromText(reply);

    const verifiedSet = new Set(verifiedNumbers.map((n) => Math.round(n)));

    // Exclude harmless conversational digits: 0, 1, 2, 3, currentYear, 24 (hours), 7 (days/week), 30 (days/month)
    const harmlessDigits = new Set([0, 1, 2, 3, currentYear, 24, 7, 30, 31, 365]);

    const suspiciousNumbers = replyNumbers.filter((n) => {
      const rounded = Math.round(n);
      return !harmlessDigits.has(rounded) && !verifiedSet.has(rounded);
    });

    if (suspiciousNumbers.length > 0) {
      // Qwen introduced invented business numbers not found anywhere in PostgreSQL results!
      return formatDeterministicResponse(collectedToolResults[0], lang, company);
    }
  }

  return reply;
}

module.exports = {
  detectPreIntent,
  extractNumbersFromToolResults,
  extractNumbersFromText,
  formatDeterministicResponse,
  validateAndGroundResponse,
};

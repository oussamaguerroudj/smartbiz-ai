/**
 * Deterministic line-item and receipt parser for OCR text.
 *
 * Extracts:
 * - Supplier / store name from header lines.
 * - Invoice / receipt date (YYYY-MM-DD, DD/MM/YYYY, etc.).
 * - Product line items (name, quantity, unitPrice).
 * - Total amount.
 */

function cleanItemName(raw) {
  if (!raw) return '';
  return raw
    .replace(/^[\d+*•#\-\s.|]+/, '') // strip leading bullets, numbers, pipes
    .replace(/[\s|]+$/, '')           // strip trailing pipes
    .replace(/\s*[-:]\s*$/, '')       // strip trailing colons/dashes
    .replace(/[\$€£]/g, '')           // strip currency symbols from name
    .replace(/\b(?:dzd|da|دج|tnd|usd|eur)\b/gi, '')
    .trim();
}

function parsePrice(raw) {
  if (!raw) return 0;
  const clean = String(raw).replace(/[\$€£\s]/g, '').replace(/,/g, '.').trim();
  const num = parseFloat(clean);
  return isNaN(num) ? 0 : Math.round(num * 100) / 100;
}

// Keywords that indicate the start of the items table
const TABLE_HEADER_REGEX = /^(?:designation|article|description|produit|item|name|nom|libell[eé]|السلعة|البيان|المنتج)\s*(?:\||\t|\s{2,}|[-:]).*?(?:qte|qty|quantit[eé]|pu|p\.u|prix|price|amount|montant|total|الكمية|السعر|الإجمالي)/i;

// Keywords that indicate the start of the totals / payment / footer section
const TOTALS_START_REGEX = /^(?:sub\s*total|sous[- ]?total|total|net\s*a\s*payer|montant\s*total|tva|tax|remise|discount|cash\b|espece|espèces?|rendu|change\b|monnaie|carte|cb|visa|mastercard|solde|reste|المجموع|الإجمالي|الضريبة|الباقي|نقدا|نقداً)/i;

// Generic non-item rows to always ignore
const EXCLUDED_ROW_REGEX = /^(?:sub\s*total|sous[- ]?total|total|tva|tax|vat|remise|discount|net|reste|solde|cash\b|espece|espèces?|rendu|change\b|monnaie|carte|cb|visa|designation|article|description|produit|item|name|qte|qty|quantit[eé]|pu|p\.u|prix|price|montant|facture|invoice|ticket|receipt|date|time|heure|tel|t[eé]l|phone|fax|n[°o]|nif|nis|rc|rib|iban|adresse|address|cashier|caissier|caissi[eè]re|manager|serveur|table|bienvenue|welcome|bonjour|merci|thank\s*you|glad\s*to\s*see|modif\.ai|www\.|http|\*\*\*|===|---|___|السلعة|البيان|الكمية|السعر|الإجمالي|المجموع|الضريبة|الباقي|نقدا|نقداً|التاريخ|تاريخ|الهاتف|هاتف|رقم|شكرا|شكراً)/i;

// Specific header metadata keywords (address, cashier, etc.)
const HEADER_METADATA_REGEX = /^(?:tel|t[eé]l|phone|fax|n[°o]|nif|nis|rc|ai|rib|iban|adresse|address|city|rue|zone|حي|شارع|مدينة|cashier|caissier|manager|serveur|table|date|heure|time|كاشير|هاتف)\b/i;

function isExcludedRow(line) {
  const trimmed = line.replace(/^[|#*•\-\s]+/, '').trim();
  return EXCLUDED_ROW_REGEX.test(trimmed);
}

function isValidItem(name, quantity, unitPrice) {
  if (!name || name.length < 2) return false;
  if (/^[\d\s.,:;/#*•\-|]+$/.test(name)) return false;
  if (isNaN(quantity) || quantity <= 0) return false;
  if (isNaN(unitPrice) || unitPrice <= 0) return false;
  if (isExcludedRow(name)) return false;
  if (HEADER_METADATA_REGEX.test(name)) return false;
  return true;
}

function normalizeDate(raw) {
  if (!raw) return null;
  const clean = raw.replace(/[./]/g, '-');
  const parts = clean.split('-');

  if (parts.length === 3) {
    if (parts[0].length === 4) {
      return `${parts[0]}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`;
    } else if (parts[2].length === 4) {
      return `${parts[2]}-${parts[1].padStart(2, '0')}-${parts[0].padStart(2, '0')}`;
    }
  }
  return clean;
}

function parseInvoiceText(ocrText) {
  if (!ocrText || typeof ocrText !== 'string') {
    return { supplier: null, date: null, items: [], total: null };
  }

  const lines = ocrText
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  if (lines.length === 0) {
    return { supplier: null, date: null, items: [], total: null };
  }

  let supplier = null;
  let date = null;
  let total = null;
  const items = [];

  // 1. Supplier detection: first clean line that isn't metadata, invoice title, or phone/address
  const nonSupplierWords = /^(facture|recu|reçu|ticket|invoice|date|heure|time|tel|tél|phone|fax|adresse|address|n°|nif|rc|bienvenue|welcome|bonjour|total|articles?|liste)/i;
  for (const line of lines.slice(0, 5)) {
    const clean = line.replace(/^[#*•\-|]\s*/, '').trim();
    if (!nonSupplierWords.test(clean) && !HEADER_METADATA_REGEX.test(clean) && clean.length > 2 && !/^\d+$/.test(clean) && !clean.includes('@') && !clean.includes('http')) {
      supplier = clean.slice(0, 150);
      break;
    }
  }

  // 2. Date detection
  const datePatterns = [
    /\b(\d{4}[-/.]\d{1,2}[-/.]\d{1,2})\b/,
    /\b(\d{1,2}[-/.]\d{1,2}[-/.]\d{4})\b/,
  ];

  for (const line of lines) {
    for (const dp of datePatterns) {
      const match = line.match(dp);
      if (match) {
        date = normalizeDate(match[1]);
        break;
      }
    }
    if (date) break;
  }

  // 3. Total detection
  const totalRegex = /(?:total\s*(?:ttc|net|a\s+payer)?|net\s*a\s*payer|montant\s*total|الإجمالي|المجموع\s*(?:الكلي)?)\s*[:=]?\s*[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?/i;
  for (const line of lines) {
    if (/sub[- ]?total|sous[- ]?total|المجموع الفرعي/i.test(line)) continue;
    const match = line.match(totalRegex);
    if (match) {
      total = parsePrice(match[1]);
      break;
    }
  }
  if (total === null) {
    const subtotalRegex = /(?:sub[- ]?total|sous[- ]?total|total\s*ht|المجموع الفرعي)\s*[:=]?\s*[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?/i;
    for (const line of lines) {
      const match = line.match(subtotalRegex);
      if (match) {
        total = parsePrice(match[1]);
        break;
      }
    }
  }

  // 4. Section splitting
  // Find where items start (after table header, if any) and where they end (at totals/summary)
  let itemStartIndex = 0;
  let itemEndIndex = lines.length;

  for (let i = 0; i < lines.length; i++) {
    const clean = lines[i].replace(/^[|#*•\-\s]+/, '').trim();
    if (TABLE_HEADER_REGEX.test(clean) || /^(?:name|article|designation)\s+(?:qty|qte)\s+(?:price|prix)/i.test(clean)) {
      itemStartIndex = i + 1;
      break;
    }
  }

  // If no table header was found, skip leading header lines (store name, address, phone, cashier, etc.)
  if (itemStartIndex === 0) {
    for (let i = 0; i < Math.min(8, lines.length); i++) {
      const clean = lines[i].replace(/^[|#*•\-\s]+/, '').trim();
      if (HEADER_METADATA_REGEX.test(clean) || nonSupplierWords.test(clean) || clean === supplier) {
        itemStartIndex = i + 1;
      } else {
        break;
      }
    }
  }

  for (let i = itemStartIndex; i < lines.length; i++) {
    const clean = lines[i].replace(/^[|#*•\-\s]+/, '').trim();
    if (TOTALS_START_REGEX.test(clean)) {
      itemEndIndex = i;
      break;
    }
  }

  const itemLines = lines.slice(itemStartIndex, itemEndIndex);

  // 5. Line items extraction
  for (const line of itemLines) {
    if (isExcludedRow(line) || HEADER_METADATA_REGEX.test(line)) continue;

    // Check pipe table row: "| Name | Qty | PU | Total |"
    if (line.includes('|')) {
      const parts = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
      if (parts.length >= 3) {
        const namePart = cleanItemName(parts[0]);
        const qtyPart = parseInt(parts[1].replace(/[^\d]/g, ''), 10);
        const pricePart = parsePrice(parts[2]);
        if (isValidItem(namePart, qtyPart || 1, pricePart)) {
          items.push({ name: namePart, quantity: qtyPart || 1, unitPrice: pricePart });
          continue;
        }
      }
    }

    // Pattern A: "Name - Qte: 3 - Prix: 180" or "Name: Qty 3 Price 180"
    const patternA = /^(?:\d+[\s.)\-]*)?(.+?)\s*[-:]\s*(?:qte|qty|quantit[eé]|الكمية|كمية)\s*[:=]?\s*(\d+)\s*[-:]\s*(?:prix|pu|unit[eé]|price|السعر|سعر)\s*[:=]?\s*[\$€£]?\s*(\d+(?:[.,]\d+)?)/i;
    let match = line.match(patternA);
    if (match) {
      const name = cleanItemName(match[1]);
      const quantity = parseInt(match[2], 10);
      const unitPrice = parsePrice(match[3]);
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    // Pattern B: "3 x Pain Baguette $9.20" or "3x Pain 25 DA"
    const patternB = /^(\d+)\s*[xX*]\s*(.+?)\s+[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?$/i;
    match = line.match(patternB);
    if (match) {
      const quantity = parseInt(match[1], 10);
      const name = cleanItemName(match[2]);
      const unitPrice = parsePrice(match[3]);
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    // Pattern C: "Pain Baguette x 3 $9.20" or "Pain x3 25"
    const patternC = /^(?:\d+[\s.)\-]*)?(.+?)\s+[xX*]\s*(\d+)\s+[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?$/i;
    match = line.match(patternC);
    if (match) {
      const name = cleanItemName(match[1]);
      const quantity = parseInt(match[2], 10);
      const unitPrice = parsePrice(match[3]);
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    // Pattern D1 (Tabular with 4 columns: Name, Qty, UnitPrice, Total):
    // e.g. "Lait Candia 1L    12    125.00    1500.00" or "Coca 330ml\t24\t$70.00\t$1680.00"
    const patternD1 = /^(?:\d+[\s.)\-]*)?(.+?)\s+(\d+)\s+[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?\s+[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?$/i;
    match = line.match(patternD1);
    if (match) {
      const name = cleanItemName(match[1]);
      const quantity = parseInt(match[2], 10);
      const unitPrice = parsePrice(match[3]);
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    // Pattern D2 (Tabular with 3 columns: Name, Qty, Price):
    // e.g. "Lorem ipsum 1 $9.20" or "Pain Baguette 2 25.00"
    const patternD2 = /^(?:\d+[\s.)\-]*)?(.+?)\s+(\d+)\s+[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?$/i;
    match = line.match(patternD2);
    if (match) {
      const name = cleanItemName(match[1]);
      const quantity = parseInt(match[2], 10);
      const unitPrice = parsePrice(match[3]);
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    // Pattern E (Simple Name and Price, default qty 1):
    // e.g. "Pain Baguette $9.20" or "Café au lait 150 DA"
    const patternE = /^(?:\d+[\s.)\-]*)?([a-zA-Z\u0600-\u06FF\s'\-_]+?)\s*[:.]*\s+[\$€£]?\s*(\d+(?:[.,]\d+)?)\s*(?:[\$€£]|dzd|da|دج)?$/i;
    match = line.match(patternE);
    if (match) {
      const name = cleanItemName(match[1]);
      const unitPrice = parsePrice(match[2]);
      if (isValidItem(name, 1, unitPrice)) {
        items.push({ name, quantity: 1, unitPrice });
        continue;
      }
    }
  }

  return {
    supplier,
    date,
    items,
    total,
  };
}

module.exports = {
  parseInvoiceText,
};

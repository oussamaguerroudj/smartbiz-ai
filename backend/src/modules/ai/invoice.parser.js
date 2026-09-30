/**
 * Deterministic line-item and receipt parser for OCR text.
 *
 * Extracts:
 * - Supplier / store name from header lines.
 * - Invoice / receipt date (YYYY-MM-DD, DD/MM/YYYY, etc.).
 * - Product line items (name, quantity, unitPrice).
 * - Total amount.
 */

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

  // Header exclusion keywords for supplier detection
  const nonSupplierWords = /^(facture|recu|reçu|ticket|invoice|date|heure|time|tel|tél|adresse|n°|bienvenue|bonjour|total|articles?|liste)/i;

  // 1. Supplier detection: first clean line that doesn't match generic header words
  for (const line of lines.slice(0, 5)) {
    if (!nonSupplierWords.test(line) && line.length > 2 && !/^\d+$/.test(line)) {
      supplier = line.replace(/^[#*•-]\s*/, '').slice(0, 150);
      break;
    }
  }

  // 2. Date detection
  const datePatterns = [
    /\b(\d{4}[-/.]\d{1,2}[-/.]\d{1,2})\b/, // 2026-09-22 or 2026/09/22
    /\b(\d{1,2}[-/.]\d{1,2}[-/.]\d{4})\b/, // 22/09/2026 or 22-09-2026
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

  // 3. Total amount detection
  const totalRegex = /(?:total|net\s+a\s+payer|montant\s+total|somme|الإجمالي|المجموع)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(?:dzd|da|دج)?/i;
  for (const line of lines) {
    const match = line.match(totalRegex);
    if (match) {
      total = parseFloat(match[1].replace(/,/g, '.'));
      break;
    }
  }

  // 4. Line items extraction
  // Pattern A: "1. Lait 1L - Qte: 3 - Prix: 180 DZD" or "Lait 1L - Qte: 3 - Prix: 180"
  const itemPatternA = /^(?:\d+[\s.)\-]*)?(.+?)\s*[-:]\s*(?:qte|qty|quantit[eé]|كمية)\s*[:=]?\s*(\d+)\s*[-:]\s*(?:prix|pu|unit[eé]|سعر)\s*[:=]?\s*(\d+(?:[.,]\d+)?)/i;

  // Pattern B: "3 x Pain Baguette 25 DZD" or "3x Pain Baguette 25"
  const itemPatternB = /^(\d+)\s*[xX*]\s*(.+?)\s+(\d+(?:[.,]\d+)?)\s*(?:dzd|da|دج)?$/i;

  // Pattern C: "Pain Baguette x 3 25" or "Pain Baguette x3 25"
  const itemPatternC = /^(?:\d+[\s.)\-]*)?(.+?)\s+[xX*]\s*(\d+)\s+(\d+(?:[.,]\d+)?)\s*(?:dzd|da|دج)?$/i;

  // Pattern D1: Tabular: "Name Quantity UnitPrice Total" e.g. "Lait 1L 24 125.00 3000.00"
  const itemPatternD1 = /^(?:\d+[\s.)\-]*)?(.+?)\s+(\d+)\s+(\d+(?:[.,]\d+)?)\s+(?:\d+(?:[.,]\d+)?)$/;

  // Pattern D2: Tabular: "Name Quantity UnitPrice" e.g. "Couscous Sim 1kg 20 85.00"
  const itemPatternD2 = /^(?:\d+[\s.)\-]*)?(.+?)\s+(\d+)\s+(\d+(?:[.,]\d+)?)$/;

  for (const line of lines) {
    // Skip subtotal/tax/total and table header lines
    if (/^(?:total|sous-total|subtotal|tva|tax|remise|discount|net|reste|designation|article|qte|qty|pu|p\.u|montant|facture|invoice|ticket|date|tel|tél|n°|التاريخ|تاريخ|رقم|السلعة|البيان|الكمية|السعر|فاتورة|المجموع|الإجمالي|شكرا|شكراً)/i.test(line)) {
      continue;
    }

    let matched = line.match(itemPatternA);
    if (matched) {
      const name = cleanItemName(matched[1]);
      const quantity = parseInt(matched[2], 10);
      const unitPrice = parseFloat(matched[3].replace(/,/g, '.'));
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    matched = line.match(itemPatternB);
    if (matched) {
      const quantity = parseInt(matched[1], 10);
      const name = cleanItemName(matched[2]);
      const unitPrice = parseFloat(matched[3].replace(/,/g, '.'));
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    matched = line.match(itemPatternC);
    if (matched) {
      const name = cleanItemName(matched[1]);
      const quantity = parseInt(matched[2], 10);
      const unitPrice = parseFloat(matched[3].replace(/,/g, '.'));
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    // Pipe-separated table row support: "| Name | Qty | PU | Total |" or "Name | Qty | PU"
    const trimmedPipes = line.replace(/^\|\s*/, '').replace(/\s*\|$/, '').trim();
    const pipeParts = trimmedPipes.split(/\s*\|\s*/);
    if (pipeParts.length >= 3) {
      const name = cleanItemName(pipeParts[0]);
      const quantity = parseInt(pipeParts[1], 10);
      const unitPrice = parseFloat(pipeParts[2].replace(/,/g, '.'));
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    matched = line.match(itemPatternD1);
    if (matched) {
      const name = cleanItemName(matched[1]);
      const quantity = parseInt(matched[2], 10);
      const unitPrice = parseFloat(matched[3].replace(/,/g, '.'));
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    matched = line.match(itemPatternD2);
    if (matched) {
      const name = cleanItemName(matched[1]);
      const quantity = parseInt(matched[2], 10);
      const unitPrice = parseFloat(matched[3].replace(/,/g, '.'));
      if (isValidItem(name, quantity, unitPrice)) {
        items.push({ name, quantity, unitPrice });
        continue;
      }
    }

    // Pattern E: "Item Name 150 DA" or "Item Name : 150" or Arabic/French text followed by number
    const itemPatternE = /^(?:\d+[\s.)\-]*)?([a-zA-Z\u0600-\u06FF\s'\-_]+?)\s*[:.]*\s+(\d+(?:[.,]\d+)?)\s*(?:dzd|da|دج)?$/i;
    matched = line.match(itemPatternE);
    if (matched) {
      const name = cleanItemName(matched[1]);
      const unitPrice = parseFloat(matched[2].replace(/,/g, '.'));
      if (isValidItem(name, 1, unitPrice) && unitPrice > 0) {
        items.push({ name, quantity: 1, unitPrice });
        continue;
      }
    }

    // Pattern F: Any line with numbers anywhere: "[qty] [name] [price]" or "[name] [qty] [price]"
    const numMatches = [...line.matchAll(/\b(\d+(?:[.,]\d+)?)\b/g)];
    if (numMatches.length >= 1) {
      const lastNum = parseFloat(numMatches[numMatches.length - 1][1].replace(/,/g, '.'));
      const textOnly = cleanItemName(line.replace(/\b\d+(?:[.,]\d+)?\b/g, '').replace(/(?:dzd|da|دج)/gi, ''));
      if (isValidItem(textOnly, 1, lastNum) && lastNum > 0 && textOnly.length >= 2) {
        const qty = numMatches.length >= 2 ? parseInt(numMatches[0][1], 10) : 1;
        items.push({ name: textOnly, quantity: Math.max(1, Math.min(1000, qty)), unitPrice: lastNum });
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

function cleanItemName(raw) {
  if (!raw) return '';
  return raw
    .replace(/^[\d+*•#\-\s.]+/, '')
    .replace(/\s*[-:]\s*$/, '')
    .trim();
}

function isValidItem(name, quantity, unitPrice) {
  if (!name || name.length < 2) return false;
  if (/^[\d\s.,:;/#*•\-]+$/.test(name)) return false;
  if (isNaN(quantity) || quantity <= 0) return false;
  if (isNaN(unitPrice) || unitPrice < 0) return false;
  // Exclude labels that are actually table headers or metadata
  const headerWords = /^(description|article|produit|item|qte|qty|prix|price|total|date|tel|tél|التاريخ|تاريخ|فاتورة|رقم)/i;
  return !headerWords.test(name);
}

function normalizeDate(raw) {
  if (!raw) return null;
  const clean = raw.replace(/[./]/g, '-');
  const parts = clean.split('-');

  if (parts.length === 3) {
    if (parts[0].length === 4) {
      // YYYY-MM-DD
      const year = parts[0];
      const month = parts[1].padStart(2, '0');
      const day = parts[2].padStart(2, '0');
      return `${year}-${month}-${day}`;
    } else if (parts[2].length === 4) {
      // DD-MM-YYYY
      const day = parts[0].padStart(2, '0');
      const month = parts[1].padStart(2, '0');
      const year = parts[2];
      return `${year}-${month}-${day}`;
    }
  }

  return clean;
}

module.exports = {
  parseInvoiceText,
};

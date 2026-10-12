/**
 * Modiri AI — Subscription & Business Configuration
 * Central source of truth for licensing, pricing, and official contact info.
 */

const RAW_WHATSAPP = process.env.SUPPORT_WHATSAPP || '0774195871';

/**
 * Normalizes an Algerian phone number to international E.164 without plus:
 * 0774195871 -> 213774195871
 */
function normalizeAlgerianWhatsApp(raw) {
  let cleaned = String(raw || '').replace(/\D/g, '');
  if (cleaned.startsWith('0')) {
    cleaned = '213' + cleaned.substring(1);
  } else if (!cleaned.startsWith('213')) {
    cleaned = '213' + cleaned;
  }
  return cleaned;
}

const NORMALIZED_WHATSAPP = normalizeAlgerianWhatsApp(RAW_WHATSAPP);

module.exports = {
  product: {
    name: 'Modiri AI',
    licenseName: 'Modiri AI — Lifetime License',
    licenseNameAr: 'رخصة Modiri AI مدى الحياة',
    licenseNameFr: 'Licence Modiri AI à vie',
    priceDzd: 15000,
    currency: 'DZD',
    trialDurationDays: 15,
    trialReminder1Hours: 48,
    trialReminder2Hours: 24,
  },

  business: {
    ownerName: process.env.BUSINESS_OWNER_NAME || 'Oussama Guerroudj',
    ownerNameAr: process.env.BUSINESS_OWNER_NAME_AR || 'أسامة قروج',
    supportEmail: process.env.SUPPORT_EMAIL || 'oussama.guerroudj@ensia.edu.dz',
    supportWhatsApp: RAW_WHATSAPP,
    whatsappNormalized: NORMALIZED_WHATSAPP,
    whatsappUrl: `https://wa.me/${NORMALIZED_WHATSAPP}`,
    address: process.env.BUSINESS_ADDRESS || 'حي بشيري العيد، وادي السلام، غليزان',
    ccpAccount: process.env.BUSINESS_CCP_ACCOUNT || '00799999002915122873',
  },

  chargily: {
    apiKey: process.env.CHARGILY_API_KEY || null,
    secretKey: process.env.CHARGILY_SECRET_KEY || process.env.CHARGILY_WEBHOOK_SECRET || null,
    mode: process.env.CHARGILY_MODE || (process.env.NODE_ENV === 'production' ? 'live' : 'test'),
    baseUrl:
      process.env.CHARGILY_BASE_URL ||
      (process.env.CHARGILY_MODE === 'live'
        ? 'https://pay.chargily.net/api/v2'
        : 'https://pay.chargily.net/test/api/v2'),
  },

  storage: {
    maxReceiptSizeBytes: 5 * 1024 * 1024, // 5 MB
    allowedMimeTypes: ['image/jpeg', 'image/png', 'application/pdf'],
    allowedExtensions: ['.jpg', '.jpeg', '.png', '.pdf'],
  },
};

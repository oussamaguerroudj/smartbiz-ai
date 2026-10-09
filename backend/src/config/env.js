require('dotenv').config();

function required(name, fallback) {
  const value = process.env[name] ?? fallback;

  if (value === undefined || value === null || String(value).trim() === '') {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return String(value).trim();
}

function positiveInt(name, fallback) {
  const raw = process.env[name] ?? fallback;
  const value = Number.parseInt(raw, 10);

  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }

  return value;
}

const nodeEnv = process.env.NODE_ENV || 'development';

const corsOrigin = process.env.CORS_ORIGIN || (
  nodeEnv === 'production' ? null : '*'
);

if (nodeEnv === 'production') {
  if (!corsOrigin) {
    throw new Error('CORS_ORIGIN is required in production');
  }
  if (!process.env.BREVO_API_KEY || String(process.env.BREVO_API_KEY).trim() === '') {
    throw new Error('BREVO_API_KEY is required in production');
  }
}

const accessSecret = required('JWT_ACCESS_SECRET');
const refreshSecret = required('JWT_REFRESH_SECRET');

if (accessSecret.length < 32) {
  throw new Error(
    'JWT_ACCESS_SECRET must be at least 32 characters',
  );
}

if (refreshSecret.length < 32) {
  throw new Error(
    'JWT_REFRESH_SECRET must be at least 32 characters',
  );
}

if (accessSecret === refreshSecret) {
  throw new Error(
    'JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be distinct',
  );
}

module.exports = {
  nodeEnv,

  port: positiveInt('PORT', '4000'),

  databaseUrl: required('DATABASE_URL'),

  jwt: {
    accessSecret,
    refreshSecret,
    accessExpires: process.env.JWT_ACCESS_EXPIRES || '30m',
    refreshExpires: process.env.JWT_REFRESH_EXPIRES || '30d',
  },

  corsOrigin,

  // ---------------------------------------------------------------
  // AI (Ch. 25  -  ZERO OpenAI dependency, self-hosted/open-source only)
  //
  // `ai` talks to a self-hosted, OpenAI-*API-compatible* inference
  // server (vLLM or Ollama) serving open-source Qwen models  -  NOT
  // OpenAI's cloud service. The `openai` npm package is reused only
  // because it's a generic HTTP client for that API *shape*; pointing
  // its `baseURL` at your own server means no request ever reaches
  // openai.com and no OpenAI account/billing is involved. See
  // backend/AI_MIGRATION.md for exact model choices and setup.
  //
  // Defaults assume a local vLLM/Ollama instance on the same machine;
  // override every value in production via .env.
  // ---------------------------------------------------------------
  ai: {
    baseUrl:
      process.env.OLLAMA_BASE_URL ||
      process.env.AI_BASE_URL ||
      (nodeEnv === 'production' ? 'https://ollama.com/v1' : 'http://localhost:11434/v1'),
    apiKey:
      process.env.OLLAMA_API_KEY ||
      process.env.AI_API_KEY ||
      (nodeEnv === 'production' ? null : 'not-needed'),
    visionModel:
      process.env.OLLAMA_VISION_MODEL ||
      process.env.AI_VISION_MODEL ||
      (nodeEnv === 'production' ? 'gemma4:31b' : 'qwen2.5vl:7b'),
    chatModel:
      process.env.OLLAMA_MODEL ||
      process.env.OLLAMA_CHAT_MODEL ||
      process.env.AI_CHAT_MODEL ||
      (nodeEnv === 'production' ? 'gemma4:31b' : 'qwen2.5:7b'),
    ocrModel:
      process.env.OLLAMA_OCR_MODEL ||
      process.env.AI_OCR_MODEL ||
      (nodeEnv === 'production' ? 'gemma4:31b' : 'glm-ocr:latest'),
    ocrServiceUrl: process.env.OCR_SERVICE_URL || null,
  },

  brevo: {
    apiKey: process.env.BREVO_API_KEY || null,
    fromEmail: process.env.BREVO_FROM_EMAIL || 'oussama.guerroudj@ensia.edu.dz',
    fromName: process.env.BREVO_FROM_NAME || 'Modiri AI',
  },

  smtp: {
    host: process.env.SMTP_HOST || null,
    port: process.env.SMTP_PORT ? positiveInt('SMTP_PORT', '587') : 587,
    user: process.env.SMTP_USER || null,
    pass: process.env.SMTP_PASS || null,
    from:
      process.env.SMTP_FROM ||
      'Modiri AI <oussama.guerroudj@ensia.edu.dz>',
  },
};
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
  if (!process.env.SMTP_HOST || String(process.env.SMTP_HOST).trim() === '') {
    throw new Error('SMTP_HOST is required in production');
  }
  if (!process.env.SMTP_PORT || String(process.env.SMTP_PORT).trim() === '') {
    throw new Error('SMTP_PORT is required in production');
  }
  if (!process.env.SMTP_USER || String(process.env.SMTP_USER).trim() === '') {
    throw new Error('SMTP_USER is required in production');
  }
  if (!process.env.SMTP_PASS || String(process.env.SMTP_PASS).trim() === '') {
    throw new Error('SMTP_PASS is required in production');
  }
  if (!process.env.SMTP_FROM || String(process.env.SMTP_FROM).trim() === '') {
    throw new Error('SMTP_FROM is required in production');
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
    baseUrl: process.env.AI_BASE_URL || 'http://localhost:11434/v1',
    // Most self-hosted servers ignore the API key entirely  -  kept only
    // because the `openai` SDK requires a non-empty string.
    apiKey: process.env.AI_API_KEY || 'not-needed',
    // Qwen2.5-VL-7B-Instruct / qwen2.5vl:7b: open-source vision-language model
    // for document and receipt structured extraction fallback.
    visionModel: process.env.AI_VISION_MODEL || 'qwen2.5vl:7b',
    // Qwen2.5-7B-Instruct / qwen2.5:7b: text-only sibling for chat/insights.
    chatModel: process.env.AI_CHAT_MODEL || 'qwen2.5:7b',
    // Specialized OCR model (glm-ocr:latest in Ollama): dedicated, fast
    // document/receipt text recognition that avoids running heavy 7B vision models.
    ocrModel: process.env.AI_OCR_MODEL || 'glm-ocr:latest',
    // Optional companion OCR microservice (PaddleOCR)  -  see
    // backend/ocr-service/. If unreachable, invoice scanning still
    // works via GLM-OCR or vision model (see ai.service.js runOcr()).
    ocrServiceUrl: process.env.OCR_SERVICE_URL || null,
  },

  smtp: {
    host: process.env.SMTP_HOST || null,
    port: positiveInt('SMTP_PORT', '587'),
    user: process.env.SMTP_USER || null,
    pass: process.env.SMTP_PASS || null,
    from:
      process.env.SMTP_FROM ||
      'Modiri AI <no-reply@modiri.ai>',
  },
};
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

if (nodeEnv === 'production' && !corsOrigin) {
  throw new Error(
    'CORS_ORIGIN is required in production',
  );
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

  openaiApiKey: process.env.OPENAI_API_KEY || null,

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
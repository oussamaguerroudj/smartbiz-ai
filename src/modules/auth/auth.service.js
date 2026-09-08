const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { withTransaction, query } = require('../../config/db');
const env = require('../../config/env');
const ApiError = require('../../utils/ApiError');

const BCRYPT_ROUNDS = 10;

function signTokens(user) {
  const payload = { sub: user.id, companyId: user.company_id, role: user.role };
  const accessToken = jwt.sign(payload, env.jwt.accessSecret, { expiresIn: env.jwt.accessExpires });
  const refreshToken = jwt.sign(payload, env.jwt.refreshSecret, { expiresIn: env.jwt.refreshExpires });
  return { accessToken, refreshToken };
}

function toPublicUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    companyId: row.company_id,
  };
}

/**
 * Registers a brand-new company + its first (owner) user, atomically.
 * Matches Spec Ch. 5 onboarding: account creation happens before
 * business-type selection in the UI, but the company row must exist
 * first since users.company_id is NOT NULL — so this creates a
 * placeholder company (business_type defaults to 'company', name
 * 'New Business') that the client immediately updates via
 * PUT /companies/me + the business-setup payload (next batch).
 */
async function register({ name, email, password }) {
  const existing = await query('SELECT id FROM users WHERE email = $1 AND deleted_at IS NULL', [
    email,
  ]);
  if (existing.rows.length > 0) {
    throw ApiError.conflict('An account with this email already exists', 'EMAIL_TAKEN');
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  const result = await withTransaction(async (client) => {
    const companyResult = await client.query(
      `INSERT INTO companies (name, business_type, currency)
       VALUES ($1, 'company', 'DZD') RETURNING id`,
      ['New Business'],
    );
    const companyId = companyResult.rows[0].id;

    const userResult = await client.query(
      `INSERT INTO users (company_id, name, email, password_hash, role)
       VALUES ($1, $2, $3, $4, 'owner') RETURNING *`,
      [companyId, name, email, passwordHash],
    );
    return userResult.rows[0];
  });

  const tokens = signTokens(result);
  return { user: toPublicUser(result), ...tokens };
}

async function login({ email, password }) {
  const result = await query('SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL', [
    email,
  ]);
  const user = result.rows[0];
  if (!user) {
    throw ApiError.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');
  }

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw ApiError.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');
  }

  const tokens = signTokens(user);
  return { user: toPublicUser(user), ...tokens };
}

/**
 * Issues a new access token from a valid refresh token. Stateless for
 * now (no server-side revocation list) — flagged as a Phase 7 security
 * hardening item, same as noted in Phase 1's architecture doc.
 */
async function refresh({ refreshToken }) {
  let payload;
  try {
    payload = jwt.verify(refreshToken, env.jwt.refreshSecret);
  } catch (err) {
    throw ApiError.unauthorized('Invalid or expired refresh token');
  }

  const result = await query('SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL', [
    payload.sub,
  ]);
  const user = result.rows[0];
  if (!user) {
    throw ApiError.unauthorized('User no longer exists');
  }

  const tokens = signTokens(user);
  return { user: toPublicUser(user), ...tokens };
}

module.exports = { register, login, refresh };

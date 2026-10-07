const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { withTransaction, query } = require('../../config/db');
const env = require('../../config/env');
const ApiError = require('../../utils/ApiError');
const { sendMail } = require('../../utils/email');
const { generateCode, hashCode, verifyCodeHash } = require('../../utils/otp');

const BCRYPT_ROUNDS = 10;
// Verification codes are intentionally very short-lived: 1 minute. After
// that the code is dead (the expiry check below rejects it even if it's
// the "right" code) and the user has to hit resend for a new one — which
// immediately overwrites/invalidates whatever code came before it.
const VERIFICATION_CODE_TTL_SECONDS = 60;
const RESET_CODE_TTL_MINUTES = 15;
const MAX_CODE_ATTEMPTS = 5;

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function signTokens(user) {
  const basePayload = {
    sub: user.id,
    companyId: user.company_id,
    role: user.role,
    emailVerified: user.email_verified === true,
  };

  const accessToken = jwt.sign(
    { ...basePayload, type: 'access' },
    env.jwt.accessSecret,
    {
      algorithm: 'HS256',
      expiresIn: env.jwt.accessExpires,
    },
  );

  const refreshToken = jwt.sign(
    { ...basePayload, type: 'refresh' },
    env.jwt.refreshSecret,
    {
      algorithm: 'HS256',
      expiresIn: env.jwt.refreshExpires,
    },
  );

  return {
    accessToken,
    refreshToken,
  };
}

function toPublicUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone || null,
    avatarUrl: row.avatar_url || null,
    role: row.role,
    companyId: row.company_id,
    businessType: row.business_type || null,
    emailVerified: row.email_verified === true,
  };
}

/** Sends the actual email — no DB write. Callers persist the code first. */
async function sendVerificationCodeEmail({ name, email, code }) {
  const safeName = escapeHtml(name);

  await sendMail({
    to: email,
    subject: 'Your Modiri AI verification code',
    html: `<p>Hi ${safeName},</p>
      <p>Your verification code is:</p>
      <p style="font-size:28px;font-weight:700;letter-spacing:4px;">${code}</p>
      <p>This code expires in 1 minute.</p>`,
  });
}

/**
 * Registration flow (rewritten):
 *
 * The account (and its `users` row) is NOT created here anymore. Until the
 * emailed code is confirmed, nothing exists in `users`/`companies` for
 * this signup — only a row in `pending_registrations`, keyed by email.
 * This is what makes "email already exists" go away for someone who
 * registered but never entered their code: there's genuinely no account
 * yet, so registering again with the same email just overwrites the
 * pending row and sends a fresh code.
 *
 * The account is only ever created — inside verifyEmail() — once the
 * correct code is confirmed.
 */
async function register({ name, email, password, industry, type }) {
  const existingUser = await query(
    'SELECT id FROM users WHERE email = $1 AND deleted_at IS NULL',
    [email],
  );

  if (existingUser.rows.length > 0) {
    throw ApiError.conflict(
      'An account with this email already exists',
      'EMAIL_TAKEN',
    );
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const code = generateCode();
  const codeHash = hashCode(code);
  const expires = new Date(
    Date.now() + VERIFICATION_CODE_TTL_SECONDS * 1000,
  );

  // One pending row per email — re-registering the same (still
  // unverified) address just replaces the name/password/code instead of
  // being blocked as a duplicate.
  try {
    await query(
      `INSERT INTO pending_registrations (
         name, email, password_hash, code_hash, code_expires, attempts, industry, type
       )
       VALUES ($1, $2, $3, $4, $5, 0, $6, $7)
       ON CONFLICT (email) DO UPDATE
         SET name = EXCLUDED.name,
             password_hash = EXCLUDED.password_hash,
             code_hash = EXCLUDED.code_hash,
             code_expires = EXCLUDED.code_expires,
             attempts = 0,
             industry = EXCLUDED.industry,
             type = EXCLUDED.type,
             updated_at = now()`,
      [
        name,
        email,
        passwordHash,
        codeHash,
        expires,
        industry ? String(industry).trim().toLowerCase() : null,
        type ? String(type).trim().toLowerCase() : null,
      ],
    );
  } catch (err) {
    // If pending_registrations table lacks industry/type columns in an older schema, fallback
    if (
      err.message &&
      (err.message.includes('column "industry"') ||
        err.message.includes('column "type"') ||
        err.message.includes('does not exist'))
    ) {
      await query(
        `INSERT INTO pending_registrations (
           name, email, password_hash, code_hash, code_expires, attempts
         )
         VALUES ($1, $2, $3, $4, $5, 0)
         ON CONFLICT (email) DO UPDATE
           SET name = EXCLUDED.name,
               password_hash = EXCLUDED.password_hash,
               code_hash = EXCLUDED.code_hash,
               code_expires = EXCLUDED.code_expires,
               attempts = 0,
               updated_at = now()`,
        [name, email, passwordHash, codeHash, expires],
      );
    } else {
      throw err;
    }
  }

  try {
    await sendVerificationCodeEmail({ name, email, code });
  } catch (err) {
    throw ApiError.internal(
      'We could not send the verification email. Please try resending the code.',
      'VERIFICATION_EMAIL_FAILED',
    );
  }

  // No tokens, no user object — there's no account yet. The client just
  // moves on to the "enter your code" screen with this email.
  return {
    email,
    pendingVerification: true,
  };
}

async function login({ email, password }) {
  const result = await query(
    `SELECT u.*, c.business_type, c.name AS company_name
     FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE u.email = $1 AND u.deleted_at IS NULL`,
    [email],
  );

  const user = result.rows[0];

  if (!user) {
    // No verified account — but if there's a matching pending signup,
    // tell the user to verify instead of a flat "invalid credentials"
    // (without leaking whether the email exists to someone guessing a
    // wrong password).
    const pendingResult = await query(
      'SELECT password_hash FROM pending_registrations WHERE email = $1',
      [email],
    );

    const pending = pendingResult.rows[0];

    if (pending) {
      const pendingMatches = await bcrypt.compare(
        password,
        pending.password_hash,
      );

      if (pendingMatches) {
        throw ApiError.forbidden(
          'Please verify your email before logging in.',
          'EMAIL_NOT_VERIFIED',
        );
      }
    }

    throw ApiError.unauthorized(
      'Invalid email or password',
      'INVALID_CREDENTIALS',
    );
  }

  const matches = await bcrypt.compare(password, user.password_hash);

  if (!matches) {
    throw ApiError.unauthorized(
      'Invalid email or password',
      'INVALID_CREDENTIALS',
    );
  }

  // Accounts only ever get created (see verifyEmail()) once verified, so
  // this should always be true — kept as a defensive check.
  if (!user.email_verified) {
    throw ApiError.forbidden(
      'Please verify your email before logging in.',
      'EMAIL_NOT_VERIFIED',
    );
  }

  const tokens = signTokens(user);

  return {
    user: toPublicUser(user),
    company: {
      id: user.company_id,
      name: user.company_name,
      businessType: user.business_type || null,
    },
    ...tokens,
  };
}

async function refresh({ refreshToken }) {
  let payload;

  try {
    payload = jwt.verify(refreshToken, env.jwt.refreshSecret, {
      algorithms: ['HS256'],
    });
  } catch (err) {
    throw ApiError.unauthorized('Invalid or expired refresh token');
  }

  if (payload.type && payload.type !== 'refresh') {
    throw ApiError.unauthorized('Invalid refresh token type');
  }

  const result = await query(
    `SELECT u.*, c.business_type, c.name AS company_name
     FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE u.id = $1 AND u.deleted_at IS NULL`,
    [payload.sub],
  );

  const user = result.rows[0];

  if (!user) {
    throw ApiError.unauthorized('User no longer exists');
  }

  if (!user.email_verified) {
    throw ApiError.forbidden(
      'Please verify your email before refreshing your session.',
      'EMAIL_NOT_VERIFIED',
    );
  }

  const tokens = signTokens(user);

  return {
    user: toPublicUser(user),
    company: {
      id: user.company_id,
      name: user.company_name,
      businessType: user.business_type || null,
    },
    ...tokens,
  };
}

/**
 * Resends a fresh code for a pending (not-yet-created) registration.
 * Unauthenticated by design — identified by email only, same as
 * register() — because at this point there's no account and therefore
 * no access token to authenticate with.
 *
 * Generating a new code immediately overwrites/invalidates the old one
 * (the old code stops working the instant this runs, not just after its
 * own 1-minute expiry).
 */
async function resendVerification({ email }) {
  const pendingResult = await query(
    'SELECT * FROM pending_registrations WHERE email = $1',
    [email],
  );

  const pending = pendingResult.rows[0];

  if (!pending) {
    const existingUser = await query(
      'SELECT id FROM users WHERE email = $1 AND deleted_at IS NULL',
      [email],
    );

    if (existingUser.rows.length > 0) {
      throw ApiError.badRequest(
        'This account is already verified',
        'ALREADY_VERIFIED',
      );
    }

    throw ApiError.notFound(
      'No pending verification found for this email — please register again',
      'NO_PENDING_REGISTRATION',
    );
  }

  const code = generateCode();
  const codeHash = hashCode(code);
  const expires = new Date(
    Date.now() + VERIFICATION_CODE_TTL_SECONDS * 1000,
  );

  await query(
    `UPDATE pending_registrations
     SET code_hash = $2,
         code_expires = $3,
         attempts = 0,
         updated_at = now()
     WHERE email = $1`,
    [email, codeHash, expires],
  );

  await sendVerificationCodeEmail({ name: pending.name, email, code });
}

/**
 * Confirms the code for a pending registration and, only on success,
 * actually creates the company + user rows. This is the point at which
 * the account starts to exist.
 *
 * SECURITY FIX (SEC-AUTH-001 & SEC-AUTH-002):
 * 1. Never issue tokens for an existing user when no pending_registrations
 *    row exists — doing so allowed zero-click account takeover of any
 *    verified account by submitting their email with any 6-digit code.
 * 2. Commit the `attempts = attempts + 1` increment before throwing
 *    INVALID_CODE so failed brute-force attempts are not rolled back.
 */
async function verifyEmail({ email, code }) {
  const txResult = await withTransaction(async (client) => {
    const pendingResult = await client.query(
      `SELECT *
       FROM pending_registrations
       WHERE email = $1
       FOR UPDATE`,
      [email],
    );

    const pending = pendingResult.rows[0];

    if (!pending) {
      const existingUserResult = await client.query(
        'SELECT id FROM users WHERE email = $1 AND deleted_at IS NULL',
        [email],
      );

      if (existingUserResult.rows.length > 0) {
        throw ApiError.badRequest(
          'Invalid or expired verification code',
          'INVALID_CODE',
        );
      }

      throw ApiError.notFound(
        'No pending verification found for this email — please register again',
        'NO_PENDING_REGISTRATION',
      );
    }

    if (new Date(pending.code_expires) < new Date()) {
      throw ApiError.badRequest(
        'This code has expired — tap resend for a new code',
        'CODE_EXPIRED',
      );
    }

    if (pending.attempts >= MAX_CODE_ATTEMPTS) {
      throw ApiError.badRequest(
        'Too many incorrect attempts — tap resend for a new code',
        'TOO_MANY_ATTEMPTS',
      );
    }

    if (!verifyCodeHash(code, pending.code_hash)) {
      await client.query(
        `UPDATE pending_registrations
         SET attempts = attempts + 1,
             updated_at = now()
         WHERE email = $1`,
        [email],
      );

      return { __invalidCode: true };
    }

    // Correct code — the account is created right now, for the first
    // time. Everything up to this point only ever touched
    // pending_registrations.
    const businessType =
      pending.type && typeof pending.type === 'string'
        ? pending.type.toLowerCase()
        : 'company';
    const companyResult = await client.query(
      `INSERT INTO companies (name, business_type, currency)
       VALUES ($1, $2, 'DZD')
       RETURNING id, business_type, name`,
      ['New Business', businessType],
    );

    const companyRow = companyResult.rows[0];
    const companyId = companyRow.id;

    const userResult = await client.query(
      `INSERT INTO users (
         company_id,
         name,
         email,
         password_hash,
         role,
         email_verified
       )
       VALUES ($1, $2, $3, $4, 'owner', true)
       RETURNING *`,
      [companyId, pending.name, email, pending.password_hash],
    );

    const user = userResult.rows[0];
    user.business_type = companyRow.business_type;
    user.company_name = companyRow.name;

    await client.query(
      'DELETE FROM pending_registrations WHERE email = $1',
      [email],
    );

    const tokens = signTokens(user);

    return {
      user: toPublicUser(user),
      company: {
        id: companyId,
        name: companyRow.name,
        businessType: companyRow.business_type,
      },
      ...tokens,
    };
  });

  if (txResult && txResult.__invalidCode) {
    throw ApiError.badRequest(
      'Incorrect code',
      'INVALID_CODE',
    );
  }

  return txResult;
}

async function requestPasswordReset({ email }) {
  const result = await query(
    'SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL',
    [email],
  );

  const user = result.rows[0];

  if (!user) {
    return;
  }

  const code = generateCode();
  const codeHash = hashCode(code);
  const expires = new Date(
    Date.now() + RESET_CODE_TTL_MINUTES * 60 * 1000,
  );

  await query(
    `INSERT INTO password_resets (
       user_id,
       code_hash,
       expires_at
     )
     VALUES ($1, $2, $3)`,
    [user.id, codeHash, expires],
  );

  const safeName = escapeHtml(user.name);

  await sendMail({
    to: user.email,
    subject: 'Reset your Modiri AI password',
    html: `<p>Hi ${safeName},</p>
      <p>Your password reset code is:</p>
      <p style="font-size:28px;font-weight:700;letter-spacing:4px;">${code}</p>
      <p>This code expires in ${RESET_CODE_TTL_MINUTES} minutes. If you didn't request this, ignore this email.</p>`,
  });
}

async function resetPassword({ email, code, newPassword }) {
  if (
    typeof newPassword !== 'string' ||
    newPassword.length < 6
  ) {
    throw ApiError.badRequest(
      'password must be at least 6 characters',
      'VALIDATION_ERROR',
    );
  }

  const txResult = await withTransaction(async (client) => {
    const userResult = await client.query(
      `SELECT *
       FROM users
       WHERE email = $1
         AND deleted_at IS NULL
       FOR UPDATE`,
      [email],
    );

    const user = userResult.rows[0];

    if (!user) {
      throw ApiError.badRequest(
        'Invalid or expired code',
        'INVALID_CODE',
      );
    }

    const resetResult = await client.query(
      `SELECT *
       FROM password_resets
       WHERE user_id = $1
         AND used_at IS NULL
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [user.id],
    );

    const reset = resetResult.rows[0];

    if (!reset) {
      throw ApiError.badRequest(
        'Invalid or expired code',
        'INVALID_CODE',
      );
    }

    if (new Date(reset.expires_at) < new Date()) {
      throw ApiError.badRequest(
        'This code has expired — request a new one',
        'CODE_EXPIRED',
      );
    }

    if (reset.attempts >= MAX_CODE_ATTEMPTS) {
      throw ApiError.badRequest(
        'Too many incorrect attempts — request a new one',
        'TOO_MANY_ATTEMPTS',
      );
    }

    if (!verifyCodeHash(code, reset.code_hash)) {
      await client.query(
        `UPDATE password_resets
         SET attempts = attempts + 1
         WHERE id = $1`,
        [reset.id],
      );

      return { __invalidCode: true };
    }

    const passwordHash = await bcrypt.hash(
      newPassword,
      BCRYPT_ROUNDS,
    );

    await client.query(
      'UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1',
      [user.id, passwordHash],
    );

    await client.query(
      'UPDATE password_resets SET used_at = now() WHERE id = $1 AND used_at IS NULL',
      [reset.id],
    );

    return { success: true };
  });

  if (txResult && txResult.__invalidCode) {
    throw ApiError.badRequest(
      'Incorrect code',
      'INVALID_CODE',
    );
  }
}

async function getProfile(userId) {
  const result = await query(
    `SELECT u.*, c.name AS company_name, c.business_type, c.currency, c.phone AS company_phone, c.address AS company_address
     FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE u.id = $1 AND u.deleted_at IS NULL`,
    [userId],
  );

  const user = result.rows[0];
  if (!user) {
    throw ApiError.notFound('User not found');
  }

  return {
    user: toPublicUser(user),
    company: {
      id: user.company_id,
      name: user.company_name,
      businessType: user.business_type,
      currency: user.currency,
      phone: user.company_phone || null,
      address: user.company_address || null,
    },
  };
}

async function updateProfile(userId, { name, email, phone, avatarUrl } = {}) {
  if (name !== undefined && (typeof name !== 'string' || name.trim().length < 2)) {
    throw ApiError.badRequest('name must be a string of at least 2 characters', 'VALIDATION_ERROR');
  }
  if (email !== undefined && (typeof email !== 'string' || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim()))) {
    throw ApiError.badRequest('A valid email is required', 'VALIDATION_ERROR');
  }
  if (phone !== undefined && phone !== null && typeof phone !== 'string') {
    throw ApiError.badRequest('phone must be a string', 'VALIDATION_ERROR');
  }
  if (avatarUrl !== undefined && avatarUrl !== null && typeof avatarUrl !== 'string') {
    throw ApiError.badRequest('avatarUrl must be a string', 'VALIDATION_ERROR');
  }

  const checkUser = await query(
    `SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL`,
    [userId],
  );
  const user = checkUser.rows[0];
  if (!user) throw ApiError.notFound('User not found');

  if (email && email.trim() !== user.email) {
    const existingEmail = await query(
      `SELECT id FROM users WHERE email = $1 AND id != $2 AND deleted_at IS NULL`,
      [email.trim(), userId],
    );
    if (existingEmail.rows.length > 0) {
      throw ApiError.conflict('An account with this email already exists', 'EMAIL_TAKEN');
    }
  }

  const updatedResult = await query(
    `UPDATE users
     SET name = COALESCE($2, name),
         email = COALESCE($3, email),
         phone = CASE WHEN $4::text IS NOT NULL THEN (CASE WHEN $4::text = '' THEN NULL ELSE $4::text END) ELSE phone END,
         avatar_url = CASE WHEN $5::text IS NOT NULL THEN (CASE WHEN $5::text = '' THEN NULL ELSE $5::text END) ELSE avatar_url END,
         updated_at = now()
     WHERE id = $1 AND deleted_at IS NULL
     RETURNING *`,
    [
      userId,
      name !== undefined ? name.trim() : null,
      email !== undefined ? email.trim() : null,
      phone !== undefined && phone !== null ? phone.trim() : null,
      avatarUrl !== undefined && avatarUrl !== null ? avatarUrl.trim() : null,
    ],
  );

  return toPublicUser(updatedResult.rows[0]);
}

async function changePassword(userId, { currentPassword, newPassword } = {}) {
  if (typeof currentPassword !== 'string' || currentPassword.length === 0) {
    throw ApiError.badRequest('currentPassword is required', 'VALIDATION_ERROR');
  }
  if (typeof newPassword !== 'string' || newPassword.length < 6) {
    throw ApiError.badRequest('newPassword must be at least 6 characters', 'VALIDATION_ERROR');
  }

  const userRes = await query(
    `SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL`,
    [userId],
  );
  const user = userRes.rows[0];
  if (!user) throw ApiError.notFound('User not found');

  const matches = await bcrypt.compare(currentPassword, user.password_hash);
  if (!matches) {
    throw ApiError.badRequest('Current password is incorrect', 'INVALID_PASSWORD');
  }

  const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
  await query(
    `UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1`,
    [userId, passwordHash],
  );

  return { success: true };
}

async function deleteAccount(userId, { password } = {}) {
  if (typeof password !== 'string' || password.length === 0) {
    throw ApiError.badRequest('password is required to confirm account deletion', 'VALIDATION_ERROR');
  }

  const userRes = await query(
    `SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL`,
    [userId],
  );
  const user = userRes.rows[0];
  if (!user) throw ApiError.notFound('User not found');

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw ApiError.badRequest('Password is incorrect to confirm account deletion', 'INVALID_PASSWORD');
  }

  return withTransaction(async (client) => {
    await client.query(
      `UPDATE users SET deleted_at = now(), updated_at = now() WHERE id = $1`,
      [userId],
    );

    if (user.role === 'owner') {
      await client.query(
        `UPDATE companies SET updated_at = now() WHERE id = $1`,
        [user.company_id],
      );
    }

    return { deleted: true };
  });
}

module.exports = {
  register,
  login,
  refresh,
  resendVerification,
  verifyEmail,
  requestPasswordReset,
  resetPassword,
  getProfile,
  updateProfile,
  changePassword,
  deleteAccount,
};
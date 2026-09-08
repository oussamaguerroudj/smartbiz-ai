const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { withTransaction, query } = require('../../config/db');
const env = require('../../config/env');
const ApiError = require('../../utils/ApiError');
const { sendMail } = require('../../utils/email');
const { generateCode, hashCode } = require('../../utils/otp');

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
  const payload = {
    sub: user.id,
    companyId: user.company_id,
    role: user.role,
    emailVerified: user.email_verified === true,
  };

  const accessToken = jwt.sign(payload, env.jwt.accessSecret, {
    expiresIn: env.jwt.accessExpires,
  });

  const refreshToken = jwt.sign(payload, env.jwt.refreshSecret, {
    expiresIn: env.jwt.refreshExpires,
  });

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
    role: row.role,
    companyId: row.company_id,
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
async function register({ name, email, password }) {
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

  try {
    await sendVerificationCodeEmail({ name, email, code });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(
      `register(): could not send verification email to ${email}:`,
      err.message,
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
    'SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL',
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
    ...tokens,
  };
}

async function refresh({ refreshToken }) {
  let payload;

  try {
    payload = jwt.verify(refreshToken, env.jwt.refreshSecret);
  } catch (err) {
    throw ApiError.unauthorized('Invalid or expired refresh token');
  }

  const result = await query(
    'SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL',
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
 * Unauthenticated by design (email + code only) — same reasoning as
 * resendVerification().
 */
async function verifyEmail({ email, code }) {
  return withTransaction(async (client) => {
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
        'SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL',
        [email],
      );

      const existingUser = existingUserResult.rows[0];

      if (existingUser) {
        // Already verified (e.g. a duplicate/late request) — treat as
        // success and hand back a session rather than erroring.
        const tokens = signTokens(existingUser);

        return {
          user: toPublicUser(existingUser),
          ...tokens,
        };
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

    if (hashCode(code) !== pending.code_hash) {
      await client.query(
        `UPDATE pending_registrations
         SET attempts = attempts + 1
         WHERE email = $1`,
        [email],
      );

      throw ApiError.badRequest(
        'Incorrect code',
        'INVALID_CODE',
      );
    }

    // Correct code — the account is created right now, for the first
    // time. Everything up to this point only ever touched
    // pending_registrations.
    const companyResult = await client.query(
      `INSERT INTO companies (name, business_type, currency)
       VALUES ($1, 'company', 'DZD')
       RETURNING id`,
      ['New Business'],
    );

    const companyId = companyResult.rows[0].id;

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

    await client.query(
      'DELETE FROM pending_registrations WHERE email = $1',
      [email],
    );

    const tokens = signTokens(user);

    return {
      user: toPublicUser(user),
      ...tokens,
    };
  });
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
  return withTransaction(async (client) => {
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

    if (hashCode(code) !== reset.code_hash) {
      await client.query(
        `UPDATE password_resets
         SET attempts = attempts + 1
         WHERE id = $1`,
        [reset.id],
      );

      throw ApiError.badRequest(
        'Incorrect code',
        'INVALID_CODE',
      );
    }

    if (
      typeof newPassword !== 'string' ||
      newPassword.length < 6
    ) {
      throw ApiError.badRequest(
        'password must be at least 6 characters',
        'VALIDATION_ERROR',
      );
    }

    const passwordHash = await bcrypt.hash(
      newPassword,
      BCRYPT_ROUNDS,
    );

    await client.query(
      'UPDATE users SET password_hash = $2 WHERE id = $1',
      [user.id, passwordHash],
    );

    await client.query(
      'UPDATE password_resets SET used_at = now() WHERE id = $1',
      [reset.id],
    );
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
};
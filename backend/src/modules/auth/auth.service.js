const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const { withTransaction, query } = require('../../config/db');
const env = require('../../config/env');
const ApiError = require('../../utils/ApiError');
const { sendMail } = require('../../utils/email');
const { generateCode, hashCode, verifyCodeHash } = require('../../utils/otp');
const { buildSuspendedDetails } = require('../../middlewares/auth.middleware');

const BCRYPT_ROUNDS = 10;
// Verification codes are intentionally very short-lived: 1 minute. After
// that the code is dead (the expiry check below rejects it even if it's
// the "right" code) and the user has to hit resend for a new one  -  which
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

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
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
    onboardingCompleted: row.onboarding_completed === true,
    emailVerified: row.email_verified === true,
    entitlementType: row.entitlement_type || 'none',
    trialStartsAt: row.trial_starts_at || null,
    trialEndsAt: row.trial_ends_at || null,
    licenseExpiresAt: row.license_expires_at || null,
    accountApprovalStatus: row.account_approval_status || 'approved',
    isSuspended: row.is_suspended === true,
    suspensionReason: row.suspension_reason || null,
    suspendedAt: row.suspended_at || null,
    authProvider: row.auth_provider || (row.google_id ? 'google' : 'local'),
    isGoogleLinked: Boolean(row.google_id),
  };
}

/** Sends the actual email  -  no DB write. Callers persist the code first. */
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
 * this signup  -  only a row in `pending_registrations`, keyed by email.
 * This is what makes "email already exists" go away for someone who
 * registered but never entered their code: there's genuinely no account
 * yet, so registering again with the same email just overwrites the
 * pending row and sends a fresh code.
 *
 * The account is only ever created  -  inside verifyEmail()  -  once the
 * correct code is confirmed.
 */
async function register({ name, email, password }) {
  const normalizedEmail = normalizeEmail(email);
  const trimmedName = String(name || '').trim();

  const existingUser = await query(
    'SELECT id FROM users WHERE lower(trim(email)) = $1 AND deleted_at IS NULL',
    [normalizedEmail],
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

  // One pending row per email  -  re-registering the same (still
  // unverified) address just replaces the name/password/code instead of
  // being blocked as a duplicate.
  await query(
    `INSERT INTO pending_registrations (
       name, email, password_hash, code_hash, code_expires, attempts
     )
     VALUES ($1, $2, $3, $4, $5, 0)
     ON CONFLICT (lower(trim(email))) DO UPDATE
       SET name = EXCLUDED.name,
           password_hash = EXCLUDED.password_hash,
           code_hash = EXCLUDED.code_hash,
           code_expires = EXCLUDED.code_expires,
           attempts = 0,
           updated_at = now()`,
    [trimmedName, normalizedEmail, passwordHash, codeHash, expires],
  );

  const domain = normalizedEmail.split('@')[1] || 'unknown';
  try {
    await sendVerificationCodeEmail({ name: trimmedName, email: normalizedEmail, code });
    // eslint-disable-next-line no-console
    console.log(`[AUTH-REGISTER] verification email dispatched successfully to recipient @${domain}`);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(`[EMAIL] Verification email failed for recipient @${domain}: status=${err.status || 500} code=${err.brevoCode || err.code || 'UNKNOWN'} message=${err.message}`);
    throw ApiError.internal(
      'We could not send the verification email. Please try resending the code.',
      'VERIFICATION_EMAIL_FAILED',
    );
  }

  // No tokens, no user object  -  there's no account yet. The client just
  // moves on to the "enter your code" screen with this email.
  return {
    email: normalizedEmail,
    pendingVerification: true,
  };
}

async function login({ email, password }) {
  const normalizedEmail = normalizeEmail(email);
  const result = await query(
    `SELECT u.*, c.business_type, c.name AS company_name, c.onboarding_completed,
            c.entitlement_type, c.trial_starts_at, c.trial_ends_at, c.license_expires_at,
            c.account_approval_status, c.is_suspended, c.suspension_reason, c.suspended_at
     FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE lower(trim(u.email)) = $1 AND u.deleted_at IS NULL`,
    [normalizedEmail],
  );

  const user = result.rows[0];

  if (!user) {
    // No verified account  -  but if there's a matching pending signup,
    // tell the user to verify instead of a flat "invalid credentials"
    // (without leaking whether the email exists to someone guessing a
    // wrong password).
    const pendingResult = await query(
      'SELECT password_hash FROM pending_registrations WHERE lower(trim(email)) = $1',
      [normalizedEmail],
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

  if (!user.password_hash) {
    throw ApiError.badRequest(
      'This account is registered with Google. Please use Continue with Google to sign in.',
      'GOOGLE_ACCOUNT',
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
  // this should always be true  -  kept as a defensive check.
  if (!user.email_verified) {
    throw ApiError.forbidden(
      'Please verify your email before logging in.',
      'EMAIL_NOT_VERIFIED',
    );
  }

  // Do NOT issue normal accessToken or refreshToken if the account is suspended!
  if (user.is_suspended === true && user.role !== 'super_admin') {
    const suspendedDetails = buildSuspendedDetails(user);
    throw ApiError.forbidden(
      suspendedDetails.suspensionReason,
      'ACCOUNT_SUSPENDED',
      suspendedDetails,
    );
  }

  const tokens = signTokens(user);

  return {
    user: toPublicUser(user),
    company: {
      id: user.company_id,
      name: user.company_name,
      businessType: user.business_type || null,
      onboardingCompleted: user.onboarding_completed === true,
      entitlementType: user.entitlement_type || 'none',
      trialStartsAt: user.trial_starts_at || null,
      trialEndsAt: user.trial_ends_at || null,
      licenseExpiresAt: user.license_expires_at || null,
      accountApprovalStatus: user.account_approval_status || 'approved',
      isSuspended: user.is_suspended === true,
      suspensionReason: user.suspension_reason || null,
      suspendedAt: user.suspended_at || null,
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
    `SELECT u.*, c.business_type, c.name AS company_name, c.onboarding_completed,
            c.entitlement_type, c.trial_starts_at, c.trial_ends_at, c.license_expires_at,
            c.account_approval_status, c.is_suspended, c.suspension_reason, c.suspended_at
     FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE u.id = $1 AND u.deleted_at IS NULL`,
    [payload.sub],
  );

  const user = result.rows[0];

  if (!user) {
    throw ApiError.unauthorized('User no longer exists', 'SESSION_REVOKED');
  }

  if (!user.email_verified) {
    throw ApiError.forbidden(
      'Please verify your email before refreshing your session.',
      'EMAIL_NOT_VERIFIED',
    );
  }

  // Reject refresh token if the account has been suspended!
  if (user.is_suspended === true && user.role !== 'super_admin') {
    const suspendedDetails = buildSuspendedDetails(user);
    throw ApiError.forbidden(
      suspendedDetails.suspensionReason,
      'ACCOUNT_SUSPENDED',
      suspendedDetails,
    );
  }

  const tokens = signTokens(user);

  return {
    user: toPublicUser(user),
    company: {
      id: user.company_id,
      name: user.company_name,
      businessType: user.business_type || null,
      onboardingCompleted: user.onboarding_completed === true,
      entitlementType: user.entitlement_type || 'none',
      trialStartsAt: user.trial_starts_at || null,
      trialEndsAt: user.trial_ends_at || null,
      licenseExpiresAt: user.license_expires_at || null,
      accountApprovalStatus: user.account_approval_status || 'approved',
      isSuspended: user.is_suspended === true,
      suspensionReason: user.suspension_reason || null,
      suspendedAt: user.suspended_at || null,
    },
    ...tokens,
  };
}

/**
 * Resends a fresh code for a pending (not-yet-created) registration.
 * Unauthenticated by design  -  identified by email only, same as
 * register()  -  because at this point there's no account and therefore
 * no access token to authenticate with.
 *
 * Generating a new code immediately overwrites/invalidates the old one
 * (the old code stops working the instant this runs, not just after its
 * own 1-minute expiry).
 */
async function resendVerification({ email }) {
  const normalizedEmail = normalizeEmail(email);
  const pendingResult = await query(
    'SELECT * FROM pending_registrations WHERE lower(trim(email)) = $1',
    [normalizedEmail],
  );

  const pending = pendingResult.rows[0];

  if (!pending) {
    const existingUser = await query(
      'SELECT id FROM users WHERE lower(trim(email)) = $1 AND deleted_at IS NULL',
      [normalizedEmail],
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
     WHERE lower(trim(email)) = $1`,
    [normalizedEmail, codeHash, expires],
  );

  const domain = normalizedEmail.split('@')[1] || 'unknown';
  try {
    await sendVerificationCodeEmail({ name: pending.name, email: normalizedEmail, code });
    // eslint-disable-next-line no-console
    console.log(`[AUTH-RESEND] verification email dispatched successfully to recipient @${domain}`);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(`[EMAIL] Resend verification email failed for recipient @${domain}: status=${err.status || 500} code=${err.brevoCode || err.code || 'UNKNOWN'} message=${err.message}`);
    throw ApiError.internal(
      'We could not send the verification email. Please try resending the code.',
      'VERIFICATION_EMAIL_FAILED',
    );
  }
}

/**
 * Confirms the code for a pending registration and, only on success,
 * actually creates the company + user rows. This is the point at which
 * the account starts to exist.
 *
 * SECURITY FIX (SEC-AUTH-001 & SEC-AUTH-002):
 * 1. Never issue tokens for an existing user when no pending_registrations
 *    row exists  -  doing so allowed zero-click account takeover of any
 *    verified account by submitting their email with any 6-digit code.
 * 2. Commit the `attempts = attempts + 1` increment before throwing
 *    INVALID_CODE so failed brute-force attempts are not rolled back.
 */
async function verifyEmail({ email, code }) {
  const normalizedEmail = normalizeEmail(email);
  const txResult = await withTransaction(async (client) => {
    const pendingResult = await client.query(
      `SELECT *
       FROM pending_registrations
       WHERE lower(trim(email)) = $1
       FOR UPDATE`,
      [normalizedEmail],
    );

    const pending = pendingResult.rows[0];

    if (!pending) {
      const existingUserResult = await client.query(
        'SELECT id FROM users WHERE lower(trim(email)) = $1 AND deleted_at IS NULL',
        [normalizedEmail],
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
         WHERE lower(trim(email)) = $1`,
        [normalizedEmail],
      );

      return { __invalidCode: true };
    }

    // Option A: verifyEmail creates company with business_type = NULL and onboarding_completed = false
    const companyName = pending.name ? `${pending.name}'s Business` : 'New Business';
    const companyResult = await client.query(
      `INSERT INTO companies (name, business_type, onboarding_completed, currency)
       VALUES ($1, NULL, false, 'DZD')
       RETURNING id, business_type, onboarding_completed, name`,
      [companyName],
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
      [companyId, pending.name, normalizedEmail, pending.password_hash],
    );

    const user = userResult.rows[0];
    user.business_type = null;
    user.onboarding_completed = false;
    user.company_name = companyRow.name;

    await client.query(
      'DELETE FROM pending_registrations WHERE lower(trim(email)) = $1',
      [normalizedEmail],
    );

    const tokens = signTokens(user);

    return {
      user: toPublicUser(user),
      company: {
        id: companyId,
        name: companyRow.name,
        businessType: null,
        onboardingCompleted: false,
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
  const normalizedEmail = normalizeEmail(email);
  const result = await query(
    'SELECT * FROM users WHERE lower(trim(email)) = $1 AND deleted_at IS NULL',
    [normalizedEmail],
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

  const normalizedEmail = normalizeEmail(email);
  const txResult = await withTransaction(async (client) => {
    const userResult = await client.query(
      `SELECT *
       FROM users
       WHERE lower(trim(email)) = $1
         AND deleted_at IS NULL
       FOR UPDATE`,
      [normalizedEmail],
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
    `SELECT u.*, c.name AS company_name, c.business_type, c.onboarding_completed, c.currency, c.phone AS company_phone, c.address AS company_address,
            c.entitlement_type, c.trial_starts_at, c.trial_ends_at, c.license_expires_at,
            c.account_approval_status, c.is_suspended, c.suspension_reason
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
      businessType: user.business_type || null,
      onboardingCompleted: user.onboarding_completed === true,
      currency: user.currency,
      phone: user.company_phone || null,
      address: user.company_address || null,
      entitlementType: user.entitlement_type || 'none',
      trialStartsAt: user.trial_starts_at || null,
      trialEndsAt: user.trial_ends_at || null,
      licenseExpiresAt: user.license_expires_at || null,
      accountApprovalStatus: user.account_approval_status || 'approved',
      isSuspended: user.is_suspended === true,
      suspensionReason: user.suspension_reason || null,
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

  if (email && email.trim().toLowerCase() !== user.email.toLowerCase()) {
    const normalizedEmail = normalizeEmail(email);
    const existingEmail = await query(
      `SELECT id FROM users WHERE lower(trim(email)) = $1 AND id != $2 AND deleted_at IS NULL`,
      [normalizedEmail, userId],
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
      email !== undefined ? normalizeEmail(email) : null,
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

  if (user.password_hash) {
    if (!currentPassword || typeof currentPassword !== 'string') {
      throw ApiError.badRequest('Current password is required', 'VALIDATION_ERROR');
    }
    const matches = await bcrypt.compare(currentPassword, user.password_hash);
    if (!matches) {
      throw ApiError.badRequest('Current password is incorrect', 'INVALID_PASSWORD');
    }
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

async function verifyPassword(userId, { password } = {}) {
  if (typeof password !== 'string' || password.length === 0) {
    throw ApiError.badRequest('Password is required', 'VALIDATION_ERROR');
  }

  const userRes = await query(
    `SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL`,
    [userId],
  );
  const user = userRes.rows[0];
  if (!user) throw ApiError.notFound('User not found');

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw ApiError.badRequest('Password is incorrect', 'INVALID_PASSWORD');
  }

  return { verified: true };
}

let googleOAuthClient;
function getGoogleOAuthClient() {
  if (!googleOAuthClient) {
    googleOAuthClient = new OAuth2Client(env.google.clientId);
  }
  return googleOAuthClient;
}

async function verifyGoogleIdToken(idToken) {
  if (!idToken || typeof idToken !== 'string' || idToken.trim() === '') {
    throw ApiError.badRequest('A valid Google ID token is required', 'MISSING_GOOGLE_TOKEN');
  }

  const clientId = env.google.clientId;
  if (!clientId || String(clientId).trim() === '') {
    throw ApiError.internal('Google OAuth is not configured on the server', 'GOOGLE_OAUTH_NOT_CONFIGURED');
  }

  const audiences = (env.google.allowedAudiences && env.google.allowedAudiences.length > 0)
    ? env.google.allowedAudiences
    : [
        clientId.trim(),
        '128675361201-s1qac05sj36egh69a054ljmqukptt4tl.apps.googleusercontent.com',
        '128675361201-qhb7u121simtqfq3nubaek2nhk0qae2f.apps.googleusercontent.com',
      ];

  const client = getGoogleOAuthClient();
  let ticket;
  try {
    ticket = await client.verifyIdToken({
      idToken: idToken.trim(),
      audience: audiences,
    });
  } catch (err) {
    throw ApiError.unauthorized('Invalid or expired Google token', 'INVALID_GOOGLE_TOKEN');
  }

  const payload = ticket.getPayload();
  if (!payload) {
    throw ApiError.unauthorized('Invalid Google token payload', 'INVALID_GOOGLE_TOKEN');
  }

  const issuer = payload.iss;
  if (issuer !== 'accounts.google.com' && issuer !== 'https://accounts.google.com') {
    throw ApiError.unauthorized('Invalid Google token issuer', 'INVALID_GOOGLE_TOKEN');
  }

  const googleId = payload.sub;
  if (!googleId || typeof googleId !== 'string' || googleId.trim() === '') {
    throw ApiError.unauthorized('Missing Google user identifier (sub)', 'INVALID_GOOGLE_TOKEN');
  }

  if (!payload.email || typeof payload.email !== 'string') {
    throw ApiError.badRequest('Google account must provide an email address', 'GOOGLE_EMAIL_MISSING');
  }

  if (payload.email_verified !== true && payload.email_verified !== 'true') {
    throw ApiError.forbidden('Google email address is not verified', 'GOOGLE_EMAIL_NOT_VERIFIED');
  }

  return {
    googleId: googleId.trim(),
    email: normalizeEmail(payload.email),
    name: String(payload.name || payload.given_name || 'Google User').trim(),
    avatarUrl: payload.picture || null,
  };
}

async function exchangeGoogleAuthCode({ code, codeVerifier, redirectUri, clientId }) {
  const targetClientId = clientId || env.google.windowsClientId;
  const clientSecret = env.google.windowsClientSecret;

  if (!clientSecret || String(clientSecret).trim() === '') {
    throw ApiError.internal(
      'Google Desktop OAuth client secret is not configured on the backend server. Please configure GOOGLE_WINDOWS_CLIENT_SECRET in the server environment.',
      'GOOGLE_CLIENT_SECRET_NOT_CONFIGURED',
    );
  }

  const tokenEndpoint = 'https://oauth2.googleapis.com/token';
  const params = new URLSearchParams({
    client_id: targetClientId,
    client_secret: clientSecret.trim(),
    code: code.trim(),
    code_verifier: codeVerifier.trim(),
    redirect_uri: redirectUri.trim(),
    grant_type: 'authorization_code',
  });

  let response;
  try {
    const fetchFn = typeof global.fetch === 'function' ? global.fetch : require('node-fetch');
    response = await fetchFn(tokenEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });
  } catch (err) {
    throw ApiError.internal('Failed to connect to Google OAuth token endpoint', 'GOOGLE_NETWORK_ERROR');
  }

  const data = await response.json();
  if (!response.ok || !data.id_token) {
    const errorType = data.error || 'token_exchange_failed';
    const errorDesc = data.error_description || errorType;
    let userFriendlyMessage = `Failed to exchange Google authorization code: ${errorDesc}`;
    if (errorType === 'invalid_client' || (typeof errorDesc === 'string' && errorDesc.toLowerCase().includes('client secret'))) {
      userFriendlyMessage = 'Google Desktop OAuth token exchange failed: invalid client secret. Ensure GOOGLE_WINDOWS_CLIENT_SECRET matches the Windows Desktop OAuth client in Google Cloud Console, not the Web client.';
    }
    throw ApiError.badRequest(userFriendlyMessage, 'TOKEN_EXCHANGE_FAILED', {
      googleError: errorType,
    });
  }

  return data.id_token;
}

async function googleSignIn({ idToken, code, codeVerifier, redirectUri, clientId }) {
  let effectiveIdToken = idToken;
  if (!effectiveIdToken && code) {
    effectiveIdToken = await exchangeGoogleAuthCode({ code, codeVerifier, redirectUri, clientId });
  }

  const { googleId, email, name, avatarUrl } = await verifyGoogleIdToken(effectiveIdToken);

  // 1. Check if user already exists with this google_id
  const googleUserResult = await query(
    `SELECT u.*, c.business_type, c.name AS company_name, c.onboarding_completed,
            c.entitlement_type, c.trial_starts_at, c.trial_ends_at, c.license_expires_at,
            c.account_approval_status, c.is_suspended, c.suspension_reason, c.suspended_at
     FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE u.google_id = $1 AND u.deleted_at IS NULL`,
    [googleId],
  );

  const existingGoogleUser = googleUserResult.rows[0];
  if (existingGoogleUser) {
    if (existingGoogleUser.is_suspended === true && existingGoogleUser.role !== 'super_admin') {
      const suspendedDetails = buildSuspendedDetails(existingGoogleUser);
      throw ApiError.forbidden(
        suspendedDetails.suspensionReason,
        'ACCOUNT_SUSPENDED',
        suspendedDetails,
      );
    }

    const tokens = signTokens(existingGoogleUser);
    return {
      user: toPublicUser(existingGoogleUser),
      company: {
        id: existingGoogleUser.company_id,
        name: existingGoogleUser.company_name,
        businessType: existingGoogleUser.business_type || null,
        onboardingCompleted: existingGoogleUser.onboarding_completed === true,
        entitlementType: existingGoogleUser.entitlement_type || 'none',
        trialStartsAt: existingGoogleUser.trial_starts_at || null,
        trialEndsAt: existingGoogleUser.trial_ends_at || null,
        licenseExpiresAt: existingGoogleUser.license_expires_at || null,
        accountApprovalStatus: existingGoogleUser.account_approval_status || 'approved',
        isSuspended: existingGoogleUser.is_suspended === true,
        suspensionReason: existingGoogleUser.suspension_reason || null,
        suspendedAt: existingGoogleUser.suspended_at || null,
      },
      ...tokens,
    };
  }

  // 2. Check if an account already exists with this email without matching google_id
  const emailUserResult = await query(
    `SELECT id, google_id, password_hash FROM users WHERE lower(trim(email)) = $1 AND deleted_at IS NULL`,
    [email],
  );

  if (emailUserResult.rows.length > 0) {
    // Non-negotiable: Never automatically merge/link accounts solely because their email addresses match!
    throw ApiError.conflict(
      'An account with this email already exists. Please sign in with your email and password to link your Google account in Settings.',
      'ACCOUNT_EXISTS_WITH_PASSWORD',
    );
  }

  // 3. New Google User: Create company and user atomically inside a transaction
  return await withTransaction(async (client) => {
    const lockCheck = await client.query(
      `SELECT id FROM users WHERE (lower(trim(email)) = $1 OR google_id = $2) AND deleted_at IS NULL FOR UPDATE`,
      [email, googleId],
    );
    if (lockCheck.rows.length > 0) {
      throw ApiError.conflict(
        'An account with this email or Google identity already exists.',
        'ACCOUNT_EXISTS',
      );
    }

    const companyName = name ? `${name}'s Business` : 'New Business';
    const trialDays = 15;
    const now = new Date();
    const trialEnds = new Date(now.getTime() + trialDays * 24 * 60 * 60 * 1000);

    const companyResult = await client.query(
      `INSERT INTO companies (
         name,
         business_type,
         onboarding_completed,
         currency,
         entitlement_type,
         trial_starts_at,
         trial_ends_at,
         account_approval_status
       )
       VALUES ($1, NULL, false, 'DZD', 'trial', $2, $3, 'approved')
       RETURNING id, business_type, onboarding_completed, name, entitlement_type, trial_starts_at, trial_ends_at`,
      [companyName, now, trialEnds],
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
         email_verified,
         google_id,
         auth_provider,
         avatar_url
       )
       VALUES ($1, $2, $3, NULL, 'owner', true, $4, 'google', $5)
       RETURNING *`,
      [companyId, name, email, googleId, avatarUrl],
    );

    const newUser = userResult.rows[0];
    newUser.business_type = null;
    newUser.onboarding_completed = false;
    newUser.company_name = companyRow.name;
    newUser.entitlement_type = companyRow.entitlement_type;
    newUser.trial_starts_at = companyRow.trial_starts_at;
    newUser.trial_ends_at = companyRow.trial_ends_at;

    await client.query(
      'DELETE FROM pending_registrations WHERE lower(trim(email)) = $1',
      [email],
    );

    const tokens = signTokens(newUser);

    return {
      user: toPublicUser(newUser),
      company: {
        id: companyId,
        name: companyRow.name,
        businessType: null,
        onboardingCompleted: false,
        entitlementType: 'trial',
        trialStartsAt: companyRow.trial_starts_at,
        trialEndsAt: companyRow.trial_ends_at,
        licenseExpiresAt: null,
        accountApprovalStatus: 'approved',
        isSuspended: false,
        suspensionReason: null,
        suspendedAt: null,
      },
      ...tokens,
    };
  });
}

async function linkGoogleAccount(userId, { idToken, code, codeVerifier, redirectUri, clientId, password } = {}) {
  let effectiveIdToken = idToken;
  if (!effectiveIdToken && code) {
    effectiveIdToken = await exchangeGoogleAuthCode({ code, codeVerifier, redirectUri, clientId });
  }

  const { googleId, email, avatarUrl } = await verifyGoogleIdToken(effectiveIdToken);

  const userResult = await query(
    `SELECT u.*, c.name AS company_name FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE u.id = $1 AND u.deleted_at IS NULL`,
    [userId],
  );

  const user = userResult.rows[0];
  if (!user) {
    throw ApiError.notFound('User not found');
  }

  if (user.password_hash) {
    if (!password || typeof password !== 'string') {
      throw ApiError.badRequest('Password confirmation is required to link a Google account', 'PASSWORD_REQUIRED');
    }
    const matches = await bcrypt.compare(password, user.password_hash);
    if (!matches) {
      throw ApiError.unauthorized('Incorrect password', 'INVALID_CREDENTIALS');
    }
  }

  const existingGoogleResult = await query(
    `SELECT id FROM users WHERE google_id = $1 AND id != $2 AND deleted_at IS NULL`,
    [googleId, userId],
  );

  if (existingGoogleResult.rows.length > 0) {
    throw ApiError.conflict(
      'This Google identity is already linked to another Modiri AI account.',
      'GOOGLE_ACCOUNT_ALREADY_LINKED',
    );
  }

  await query(
    `UPDATE users
     SET google_id = $1,
         auth_provider = CASE WHEN auth_provider = 'local' THEN 'hybrid' ELSE auth_provider END,
         avatar_url = COALESCE(avatar_url, $2),
         updated_at = now()
     WHERE id = $3`,
    [googleId, avatarUrl, userId],
  );

  return {
    success: true,
    message: 'Google account linked successfully.',
    googleEmail: email,
  };
}

async function unlinkGoogleAccount(userId, { password } = {}) {
  const userResult = await query(
    `SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL`,
    [userId],
  );
  const user = userResult.rows[0];
  if (!user) {
    throw ApiError.notFound('User not found');
  }

  if (!user.google_id) {
    throw ApiError.badRequest('No Google account is linked to this user', 'NOT_LINKED');
  }

  if (!user.password_hash) {
    throw ApiError.badRequest(
      'You must set a password in your account settings before unlinking your Google account.',
      'PASSWORD_NOT_SET',
    );
  }

  if (!password || typeof password !== 'string') {
    throw ApiError.badRequest('Password confirmation is required to unlink Google account', 'PASSWORD_REQUIRED');
  }

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw ApiError.unauthorized('Incorrect password', 'INVALID_CREDENTIALS');
  }

  await query(
    `UPDATE users
     SET google_id = NULL,
         auth_provider = 'local',
         updated_at = now()
     WHERE id = $1`,
    [userId],
  );

  return {
    success: true,
    message: 'Google account unlinked successfully.',
  };
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
  verifyPassword,
  verifyGoogleIdToken,
  googleSignIn,
  linkGoogleAccount,
  unlinkGoogleAccount,
};
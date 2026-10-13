const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query, withTransaction } = require('../../config/db');
const env = require('../../config/env');
const ApiError = require('../../utils/ApiError');

function signAdminToken(user) {
  const payload = {
    sub: user.id,
    companyId: user.company_id,
    role: user.role,
    emailVerified: user.email_verified === true,
    type: 'access',
  };

  const accessToken = jwt.sign(payload, env.jwt.accessSecret, {
    algorithm: 'HS256',
    expiresIn: '8h', // Dedicated admin session
  });

  return {
    accessToken,
    admin: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
    },
  };
}

async function adminLogin({ email, password }) {
  const normalizedEmail = String(email || '').trim().toLowerCase();

  const res = await query(
    `SELECT u.*, c.name AS company_name
     FROM users u
     LEFT JOIN companies c ON c.id = u.company_id
     WHERE lower(trim(u.email)) = $1
       AND u.deleted_at IS NULL`,
    [normalizedEmail],
  );

  const user = res.rows[0];
  if (!user) {
    throw ApiError.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');
  }

  // Strict role check: MUST be super_admin or support
  if (user.role !== 'super_admin' && user.role !== 'support') {
    throw ApiError.forbidden(
      'Administrative privileges required to access the admin portal',
      'ADMIN_ACCESS_DENIED',
    );
  }

  const matches = await bcrypt.compare(password, user.password_hash);
  if (!matches) {
    throw ApiError.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');
  }

  return signAdminToken(user);
}

async function getOverviewMetrics() {
  const now = new Date();
  const in48h = new Date(now.getTime() + 48 * 60 * 60 * 1000);
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const [
    totalUsersRes,
    verifiedUsersRes,
    pendingApprovalRes,
    activeTrialsRes,
    expiring48hRes,
    expiring24hRes,
    expiredTrialsRes,
    lifetimeRes,
    temporaryRes,
    pendingChargilyRes,
    failedPaymentsRes,
    pendingManualRes,
    newSupportRes,
    newFeedbackRes,
    suspendedAccountsRes,
    openAppealsRes,
  ] = await Promise.all([
    query('SELECT count(*)::int AS count FROM users WHERE deleted_at IS NULL'),
    query('SELECT count(*)::int AS count FROM users WHERE email_verified = true AND deleted_at IS NULL'),
    query("SELECT count(*)::int AS count FROM companies WHERE account_approval_status = 'pending'"),
    query("SELECT count(*)::int AS count FROM companies WHERE entitlement_type = 'trial' AND trial_ends_at > now() AND is_suspended = false"),
    query("SELECT count(*)::int AS count FROM companies WHERE entitlement_type = 'trial' AND trial_ends_at <= $1 AND trial_ends_at > $2 AND is_suspended = false", [in48h, in24h]),
    query("SELECT count(*)::int AS count FROM companies WHERE entitlement_type = 'trial' AND trial_ends_at <= $1 AND trial_ends_at > now() AND is_suspended = false", [in24h]),
    query("SELECT count(*)::int AS count FROM companies WHERE entitlement_type = 'trial' AND trial_ends_at <= now()"),
    query("SELECT count(*)::int AS count FROM companies WHERE entitlement_type = 'lifetime'"),
    query("SELECT count(*)::int AS count FROM companies WHERE entitlement_type = 'temporary' AND license_expires_at > now()"),
    query("SELECT count(*)::int AS count FROM payment_orders WHERE payment_method = 'chargily' AND status = 'pending'"),
    query("SELECT count(*)::int AS count FROM payment_orders WHERE status = 'failed'"),
    query("SELECT count(*)::int AS count FROM manual_payment_requests WHERE status IN ('pending', 'under_review')"),
    query("SELECT count(*)::int AS count FROM support_messages WHERE status = 'new'"),
    query("SELECT count(*)::int AS count FROM feedback_submissions WHERE status = 'new'"),
    query('SELECT count(*)::int AS count FROM companies WHERE is_suspended = true'),
    query("SELECT count(*)::int AS count FROM support_messages WHERE category = 'suspension_appeal' AND status IN ('new', 'in_progress')"),
  ]);

  return {
    totalAccounts: totalUsersRes.rows[0].count,
    verifiedAccounts: verifiedUsersRes.rows[0].count,
    pendingApproval: pendingApprovalRes.rows[0].count,
    activeTrials: activeTrialsRes.rows[0].count,
    trialsExpiring48h: expiring48hRes.rows[0].count,
    trialsExpiring24h: expiring24hRes.rows[0].count,
    expiredTrials: expiredTrialsRes.rows[0].count,
    lifetimeLicenses: lifetimeRes.rows[0].count,
    temporaryLicenses: temporaryRes.rows[0].count,
    pendingChargilyPayments: pendingChargilyRes.rows[0].count,
    failedPayments: failedPaymentsRes.rows[0].count,
    manualPaymentsUnderReview: pendingManualRes.rows[0].count,
    unansweredSupportMessages: newSupportRes.rows[0].count,
    unreviewedFeedback: newFeedbackRes.rows[0].count,
    suspendedAccounts: suspendedAccountsRes.rows[0].count,
    openAppeals: openAppealsRes.rows[0].count,
  };
}

async function listUsers({ page = 1, limit = 20, search = '', filter = 'all' }) {
  const p = Math.max(1, Number.parseInt(page, 10) || 1);
  const l = Math.min(100, Math.max(1, Number.parseInt(limit, 10) || 20));
  const offset = (p - 1) * l;

  const conditions = ['u.deleted_at IS NULL'];
  const params = [];

  if (search && search.trim()) {
    params.push(`%${search.trim().toLowerCase()}%`);
    conditions.push(
      `(lower(u.name) LIKE $${params.length} OR lower(u.email) LIKE $${params.length} OR lower(coalesce(c.name, '')) LIKE $${params.length})`,
    );
  }

  const now = new Date();
  const in48h = new Date(now.getTime() + 48 * 60 * 60 * 1000);
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  if (filter === 'pending_approval') {
    conditions.push("c.account_approval_status = 'pending'");
  } else if (filter === 'active_trial') {
    conditions.push("c.entitlement_type = 'trial' AND c.trial_ends_at > now() AND c.is_suspended = false");
  } else if (filter === 'expiring_48h') {
    params.push(in48h);
    const p1 = params.length;
    params.push(in24h);
    const p2 = params.length;
    conditions.push(`c.entitlement_type = 'trial' AND c.trial_ends_at <= $${p1} AND c.trial_ends_at > $${p2} AND c.is_suspended = false`);
  } else if (filter === 'expiring_24h') {
    params.push(in24h);
    const p1 = params.length;
    conditions.push(`c.entitlement_type = 'trial' AND c.trial_ends_at <= $${p1} AND c.trial_ends_at > now() AND c.is_suspended = false`);
  } else if (filter === 'expired_trial') {
    conditions.push("c.entitlement_type = 'trial' AND c.trial_ends_at <= now()");
  } else if (filter === 'lifetime') {
    conditions.push("c.entitlement_type = 'lifetime'");
  } else if (filter === 'temporary') {
    conditions.push("c.entitlement_type = 'temporary' AND c.license_expires_at > now()");
  } else if (filter === 'suspended') {
    conditions.push('c.is_suspended = true');
  } else if (filter === 'pending_manual_payment') {
    conditions.push("EXISTS (SELECT 1 FROM manual_payment_requests mr WHERE mr.company_id = c.id AND mr.status IN ('pending', 'under_review'))");
  }

  const whereClause = conditions.join(' AND ');

  const countQuery = `
    SELECT count(*)::int AS total
    FROM users u
    LEFT JOIN companies c ON c.id = u.company_id
    WHERE ${whereClause}
  `;
  const countRes = await query(countQuery, params);
  const total = countRes.rows[0].total;

  params.push(l);
  const limitIdx = params.length;
  params.push(offset);
  const offsetIdx = params.length;

  const dataQuery = `
    SELECT u.id, u.name, u.email, u.phone, u.role, u.email_verified, u.created_at,
           c.id AS company_id, c.name AS company_name, c.business_type,
           c.entitlement_type, c.trial_starts_at, c.trial_ends_at,
           c.license_expires_at, c.account_approval_status, c.is_suspended,
           c.suspension_reason
    FROM users u
    LEFT JOIN companies c ON c.id = u.company_id
    WHERE ${whereClause}
    ORDER BY u.created_at DESC
    LIMIT $${limitIdx} OFFSET $${offsetIdx}
  `;

  const dataRes = await query(dataQuery, params);

  return {
    users: dataRes.rows.map((row) => ({
      id: row.id,
      name: row.name,
      email: row.email,
      phone: row.phone,
      role: row.role,
      emailVerified: row.email_verified === true,
      createdAt: row.created_at,
      companyId: row.company_id,
      companyName: row.company_name,
      businessType: row.business_type,
      entitlementType: row.entitlement_type || 'none',
      trialStartsAt: row.trial_starts_at,
      trialEndsAt: row.trial_ends_at,
      licenseExpiresAt: row.license_expires_at,
      accountApprovalStatus: row.account_approval_status || 'approved',
      isSuspended: row.is_suspended === true,
      suspensionReason: row.suspension_reason,
    })),
    pagination: {
      total,
      page: p,
      limit: l,
      totalPages: Math.ceil(total / l) || 1,
    },
  };
}

async function grantLifetimeLicense({ companyId, adminId, reason }) {
  if (!reason || String(reason).trim().length < 3) {
    throw ApiError.badRequest('A justification reason is required to grant a lifetime license', 'REASON_REQUIRED');
  }

  return withTransaction(async (client) => {
    const compRes = await client.query(
      'SELECT id, entitlement_type, license_expires_at FROM companies WHERE id = $1 FOR UPDATE',
      [companyId],
    );
    const company = compRes.rows[0];
    if (!company) throw ApiError.notFound('Company not found');

    const prevEntitlement = company.entitlement_type;

    await client.query(
      `UPDATE companies
       SET entitlement_type = 'lifetime',
           entitlement_granted_at = now(),
           entitlement_granted_by = $2,
           updated_at = now()
       WHERE id = $1`,
      [companyId, adminId],
    );

    await client.query(
      `INSERT INTO license_audit_logs (
         company_id, actor_id, action, previous_entitlement,
         new_entitlement, reason
       ) VALUES ($1, $2, 'grant_lifetime', $3, 'lifetime', $4)`,
      [companyId, adminId, prevEntitlement, String(reason).trim()],
    );

    // Notify company owner
    const ownerRes = await client.query(
      "SELECT id FROM users WHERE company_id = $1 AND role = 'owner' AND deleted_at IS NULL LIMIT 1",
      [companyId],
    );
    if (ownerRes.rows[0]) {
      await client.query(
        `INSERT INTO notifications (company_id, user_id, type, title, body)
         VALUES ($1, $2, 'license_granted', $3, $4)`,
        [
          companyId,
          ownerRes.rows[0].id,
          'Lifetime License Granted | تم منح رخصة مدى الحياة',
          `An administrator has granted your account a Modiri AI Lifetime License. Reason: ${reason}`,
        ],
      );
    }

    return { success: true, companyId, entitlementType: 'lifetime' };
  });
}

function addCalendarMonths(startDate, months) {
  const d = new Date(startDate);
  const targetDay = d.getDate();
  d.setDate(1);
  d.setMonth(d.getMonth() + months);
  const daysInTargetMonth = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  d.setDate(Math.min(targetDay, daysInTargetMonth));
  return d;
}

/**
 * Grants a temporary license with exact duration calculation.
 * Presets: '15d', '1m', '3m', '6m', '1y', or custom integer days.
 */
async function grantTemporaryLicense({ companyId, adminId, durationPreset, customDays, reason }) {
  if (!reason || String(reason).trim().length < 3) {
    throw ApiError.badRequest('A justification reason is required', 'REASON_REQUIRED');
  }

  const now = new Date();
  let expiresAt;

  if (durationPreset === '15d') {
    expiresAt = new Date(now.getTime() + 15 * 24 * 60 * 60 * 1000);
  } else if (durationPreset === '1m') {
    expiresAt = addCalendarMonths(now, 1);
  } else if (durationPreset === '3m') {
    expiresAt = addCalendarMonths(now, 3);
  } else if (durationPreset === '6m') {
    expiresAt = addCalendarMonths(now, 6);
  } else if (durationPreset === '1y') {
    expiresAt = addCalendarMonths(now, 12);
  } else if (durationPreset === 'custom') {
    const days = Number.parseInt(customDays, 10);
    if (Number.isNaN(days) || days <= 0 || days > 3650) {
      throw ApiError.badRequest('Custom days must be a positive integer up to 3650', 'VALIDATION_ERROR');
    }
    expiresAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
  } else {
    throw ApiError.badRequest('Invalid duration preset. Must be 15d, 1m, 3m, 6m, 1y, or custom', 'INVALID_DURATION');
  }

  return withTransaction(async (client) => {
    const compRes = await client.query(
      'SELECT id, entitlement_type, license_expires_at FROM companies WHERE id = $1 FOR UPDATE',
      [companyId],
    );
    const company = compRes.rows[0];
    if (!company) throw ApiError.notFound('Company not found');

    const prevEntitlement = company.entitlement_type;
    const prevExpires = company.license_expires_at;

    await client.query(
      `UPDATE companies
       SET entitlement_type = 'temporary',
           license_expires_at = $2,
           entitlement_granted_at = now(),
           entitlement_granted_by = $3,
           updated_at = now()
       WHERE id = $1`,
      [companyId, expiresAt, adminId],
    );

    await client.query(
      `INSERT INTO license_audit_logs (
         company_id, actor_id, action, previous_entitlement,
         new_entitlement, previous_expires_at, new_expires_at, reason, metadata
       ) VALUES ($1, $2, 'grant_temporary', $3, 'temporary', $4, $5, $6, $7)`,
      [
        companyId,
        adminId,
        prevEntitlement,
        prevExpires,
        expiresAt,
        String(reason).trim(),
        JSON.stringify({ durationPreset, customDays }),
      ],
    );

    return {
      success: true,
      companyId,
      entitlementType: 'temporary',
      licenseExpiresAt: expiresAt,
    };
  });
}

/**
 * Extends a temporary license: adds specified duration to existing valid expiration date
 * (or starts from now if already expired).
 */
async function extendTemporaryLicense({ companyId, adminId, daysToAdd, reason }) {
  const days = Number.parseInt(daysToAdd, 10);
  if (Number.isNaN(days) || days <= 0 || days > 3650) {
    throw ApiError.badRequest('daysToAdd must be a positive integer', 'VALIDATION_ERROR');
  }

  return withTransaction(async (client) => {
    const compRes = await client.query(
      'SELECT id, entitlement_type, license_expires_at FROM companies WHERE id = $1 FOR UPDATE',
      [companyId],
    );
    const company = compRes.rows[0];
    if (!company) throw ApiError.notFound('Company not found');

    const now = new Date();
    let baseTime = now;
    if (company.license_expires_at && new Date(company.license_expires_at) > now) {
      baseTime = new Date(company.license_expires_at);
    }

    const newExpiresAt = new Date(baseTime.getTime() + days * 24 * 60 * 60 * 1000);

    await client.query(
      `UPDATE companies
       SET entitlement_type = 'temporary',
           license_expires_at = $2,
           updated_at = now()
       WHERE id = $1`,
      [companyId, newExpiresAt],
    );

    await client.query(
      `INSERT INTO license_audit_logs (
         company_id, actor_id, action, previous_entitlement,
         new_entitlement, previous_expires_at, new_expires_at, reason
       ) VALUES ($1, $2, 'extend_license', $3, 'temporary', $4, $5, $6)`,
      [
        companyId,
        adminId,
        company.entitlement_type,
        company.license_expires_at,
        newExpiresAt,
        reason || 'License extended by administrator',
      ],
    );

    return {
      success: true,
      companyId,
      newExpiresAt,
    };
  });
}

async function setAccountSuspension({ companyId, adminId, isSuspended, reason, message }) {
  const suspendFlag = isSuspended === true;
  const trimmedReason = typeof reason === 'string' ? reason.trim() : '';
  const trimmedMessage = typeof message === 'string' ? message.trim() : '';
  const effectiveReason = trimmedMessage || trimmedReason;

  if (suspendFlag && (!effectiveReason || effectiveReason.length < 3)) {
    throw ApiError.badRequest(
      'A suspension reason or user-facing message (at least 3 characters) is required when suspending an account.',
      'SUSPENSION_REASON_REQUIRED',
    );
  }

  return withTransaction(async (client) => {
    const compRes = await client.query(
      'SELECT id, name, is_suspended, entitlement_type FROM companies WHERE id = $1 FOR UPDATE',
      [companyId],
    );
    const company = compRes.rows[0];
    if (!company) throw ApiError.notFound('Company not found');

    const updateRes = await client.query(
      `UPDATE companies
       SET is_suspended = $2,
           suspension_reason = $3,
           suspended_at = CASE WHEN $2 THEN now() ELSE NULL END,
           updated_at = now()
       WHERE id = $1
       RETURNING id, is_suspended, suspension_reason, suspended_at`,
      [companyId, suspendFlag, suspendFlag ? effectiveReason : null],
    );

    const updated = updateRes.rows[0];

    await client.query(
      `INSERT INTO license_audit_logs (
         company_id, actor_id, action, reason, metadata
       ) VALUES ($1, $2, $3, $4, $5)`,
      [
        companyId,
        adminId,
        suspendFlag ? 'suspend' : 'restore',
        effectiveReason || (suspendFlag ? 'Suspended by administrator' : 'Access restored by administrator'),
        JSON.stringify({
          isSuspended: suspendFlag,
          reason: trimmedReason || effectiveReason || null,
          message: trimmedMessage || effectiveReason || null,
        }),
      ],
    );

    // If restoring access, automatically mark open suspension appeals as answered
    if (!suspendFlag) {
      await client.query(
        `UPDATE support_messages
         SET status = 'answered',
             admin_notes = COALESCE(admin_notes || E'\\n', '') || $2,
             assigned_to = COALESCE(assigned_to, $3),
             updated_at = now()
         WHERE company_id = $1
           AND category = 'suspension_appeal'
           AND status IN ('new', 'in_progress')`,
        [
          companyId,
          effectiveReason
            ? `Account reactivated by administrator: ${effectiveReason}`
            : 'Account reactivated by administrator.',
          adminId,
        ],
      );
    }

    return {
      success: true,
      companyId,
      isSuspended: updated.is_suspended === true,
      suspensionReason: updated.suspension_reason || null,
      suspendedAt: updated.suspended_at || null,
    };
  });
}

async function reviewAccountApproval({ companyId, adminId, status, notes }) {
  if (status !== 'approved' && status !== 'rejected') {
    throw ApiError.badRequest('status must be either approved or rejected', 'VALIDATION_ERROR');
  }

  return withTransaction(async (client) => {
    const compRes = await client.query(
      'SELECT id, account_approval_status FROM companies WHERE id = $1 FOR UPDATE',
      [companyId],
    );
    const company = compRes.rows[0];
    if (!company) throw ApiError.notFound('Company not found');

    await client.query(
      `UPDATE companies
       SET account_approval_status = $2,
           approval_reviewed_at = now(),
           approval_reviewed_by = $3,
           updated_at = now()
       WHERE id = $1`,
      [companyId, status, adminId],
    );

    await client.query(
      `INSERT INTO license_audit_logs (
         company_id, actor_id, action, reason
       ) VALUES ($1, $2, $3, $4)`,
      [
        companyId,
        adminId,
        status === 'approved' ? 'approve_account' : 'reject_account',
        notes || `Account ${status} by administrator`,
      ],
    );

    return { success: true, companyId, status };
  });
}

async function listManualPayments() {
  const res = await query(
    `SELECT r.id, r.order_id, r.company_id, r.user_id, r.amount, r.currency,
            r.transfer_reference, r.receipt_storage_path, r.receipt_original_filename,
            r.receipt_mime_type, r.receipt_file_size, r.receipt_uploaded_at,
            r.status, r.reviewed_by, r.reviewed_at, r.rejection_reason, r.admin_notes,
            r.created_at, r.updated_at,
            o.order_number, u.name AS user_name, u.email AS user_email,
            c.name AS company_name
     FROM manual_payment_requests r
     JOIN users u ON u.id = r.user_id
     JOIN companies c ON c.id = r.company_id
     LEFT JOIN payment_orders o ON o.id = r.order_id
     ORDER BY
       CASE WHEN r.status = 'under_review' THEN 0
            WHEN r.status = 'pending' THEN 1
            ELSE 2 END,
       r.created_at DESC`,
  );

  return res.rows;
}

async function decideManualPayment({ requestId, adminId, decision, rejectionReason, adminNotes }) {
  if (decision !== 'approve' && decision !== 'reject') {
    throw ApiError.badRequest('decision must be approve or reject', 'VALIDATION_ERROR');
  }

  if (decision === 'reject' && (!rejectionReason || String(rejectionReason).trim().length < 3)) {
    throw ApiError.badRequest('A rejection reason is required', 'REJECTION_REASON_REQUIRED');
  }

  return withTransaction(async (client) => {
    const reqRes = await client.query(
      'SELECT * FROM manual_payment_requests WHERE id = $1 FOR UPDATE',
      [requestId],
    );
    const request = reqRes.rows[0];
    if (!request) throw ApiError.notFound('Payment request not found');

    if (request.status === 'approved') {
      throw ApiError.badRequest('This request is already approved', 'ALREADY_APPROVED');
    }

    if (decision === 'approve') {
      // Prevent duplicate reuse of an approved transfer reference
      if (request.transfer_reference && String(request.transfer_reference).trim()) {
        const dupRefRes = await client.query(
          `SELECT id, company_id FROM manual_payment_requests
           WHERE lower(trim(transfer_reference)) = lower(trim($1))
             AND status = 'approved'
             AND id != $2
           LIMIT 1`,
          [request.transfer_reference, requestId],
        );
        if (dupRefRes.rows.length > 0) {
          throw ApiError.badRequest(
            `Transfer reference '${request.transfer_reference}' has already been approved for another payment`,
            'DUPLICATE_TRANSFER_REFERENCE',
          );
        }
      }

      // 1. Mark request approved
      await client.query(
        `UPDATE manual_payment_requests
         SET status = 'approved',
             reviewed_by = $2,
             reviewed_at = now(),
             admin_notes = $3,
             updated_at = now()
         WHERE id = $1`,
        [requestId, adminId, adminNotes || 'Approved by administrator'],
      );

      // 2. Mark order paid
      if (request.order_id) {
        await client.query(
          `UPDATE payment_orders
           SET status = 'paid', paid_at = now(), updated_at = now()
           WHERE id = $1`,
          [request.order_id],
        );
      }

      // 3. Activate lifetime license transactionally
      await client.query(
        `UPDATE companies
         SET entitlement_type = 'lifetime',
             entitlement_granted_at = now(),
             entitlement_granted_by = $2,
             updated_at = now()
         WHERE id = $1`,
        [request.company_id, adminId],
      );

      // 4. Audit Log
      await client.query(
        `INSERT INTO license_audit_logs (
           company_id, user_id, actor_id, action, previous_entitlement,
           new_entitlement, reason, metadata
         ) VALUES ($1, $2, $3, 'approve_manual_payment', 'trial', 'lifetime',
           'Manual CCP payment verified and approved', $4)`,
        [
          request.company_id,
          request.user_id,
          adminId,
          JSON.stringify({ requestId, transferReference: request.transfer_reference }),
        ],
      );

      // 5. In-app notification
      await client.query(
        `INSERT INTO notifications (company_id, user_id, type, title, body)
         VALUES ($1, $2, 'license_granted', $3, $4)`,
        [
          request.company_id,
          request.user_id,
          'Manual Payment Approved | تم قبول وصل الدفع وتفعيل الرخصة',
          'Your manual CCP payment has been verified by the administrator. Your Modiri AI Lifetime License is permanently active!\n\nتم التحقق من وصل الدفع الخاص بك واعتماده من قبل الإدارة. تم تفعيل رخصة Modiri AI مدى الحياة بشكل دائم!',
        ],
      );

      return { success: true, status: 'approved', companyId: request.company_id };
    } else {
      // Reject
      await client.query(
        `UPDATE manual_payment_requests
         SET status = 'rejected',
             rejection_reason = $2,
             reviewed_by = $3,
             reviewed_at = now(),
             admin_notes = $4,
             updated_at = now()
         WHERE id = $1`,
        [requestId, String(rejectionReason).trim(), adminId, adminNotes || null],
      );

      if (request.order_id) {
        await client.query(
          `UPDATE payment_orders
           SET status = 'failed', updated_at = now()
           WHERE id = $1`,
          [request.order_id],
        );
      }

      await client.query(
        `INSERT INTO license_audit_logs (
           company_id, user_id, actor_id, action, reason, metadata
         ) VALUES ($1, $2, $3, 'reject_manual_payment', $4, $5)`,
        [
          request.company_id,
          request.user_id,
          adminId,
          String(rejectionReason).trim(),
          JSON.stringify({ requestId }),
        ],
      );

      await client.query(
        `INSERT INTO notifications (company_id, user_id, type, title, body)
         VALUES ($1, $2, 'payment_update', $3, $4)`,
        [
          request.company_id,
          request.user_id,
          'Receipt Verification Rejected | تنبيه بخصوص وصل الدفع',
          `Your manual payment receipt was rejected: ${rejectionReason}. You may re-upload a clear receipt from the purchase screen.`,
        ],
      );

      return { success: true, status: 'rejected', companyId: request.company_id };
    }
  });
}

async function listSupportMessages({ status = 'all', category = 'all' } = {}) {
  const conditions = [];
  const params = [];

  if (status && status !== 'all') {
    params.push(status);
    conditions.push(`s.status = $${params.length}`);
  }

  if (category && category !== 'all') {
    params.push(category);
    conditions.push(`s.category = $${params.length}`);
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const res = await query(
    `SELECT s.*,
            u.name AS user_account_name,
            c.name AS company_name,
            c.is_suspended AS company_is_suspended,
            c.suspension_reason AS company_suspension_reason,
            c.suspended_at AS company_suspended_at,
            c.entitlement_type AS company_entitlement_type
     FROM support_messages s
     LEFT JOIN users u ON u.id = s.user_id
     LEFT JOIN companies c ON c.id = s.company_id
     ${where}
     ORDER BY
       CASE WHEN s.category = 'suspension_appeal' AND s.status IN ('new', 'in_progress') THEN 0
            WHEN s.status = 'new' THEN 1
            ELSE 2 END,
       s.created_at DESC
     LIMIT 200`,
    params,
  );

  return res.rows;
}

async function updateSupportStatus({ messageId, adminId, status, adminNotes, publicReply }) {
  const colRes = await query(`
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'support_messages' AND column_name = 'public_reply'
  `);
  const hasPublicReply = colRes.rows && colRes.rows.length > 0;

  let res;
  if (hasPublicReply) {
    res = await query(
      `UPDATE support_messages
       SET status = coalesce($2, status),
           admin_notes = coalesce($3, admin_notes),
           public_reply = coalesce($4, public_reply),
           assigned_to = coalesce($5, assigned_to),
           updated_at = now()
       WHERE id = $1
       RETURNING *`,
      [
        messageId,
        status || null,
        adminNotes !== undefined ? adminNotes : null,
        publicReply !== undefined ? publicReply : null,
        adminId,
      ],
    );
  } else {
    res = await query(
      `UPDATE support_messages
       SET status = coalesce($2, status),
           admin_notes = coalesce($3, admin_notes),
           assigned_to = coalesce($4, assigned_to),
           updated_at = now()
       WHERE id = $1
       RETURNING *`,
      [
        messageId,
        status || null,
        adminNotes !== undefined ? adminNotes : null,
        adminId,
      ],
    );
  }

  if (!res.rows[0]) throw ApiError.notFound('Support message not found');
  return res.rows[0];
}

async function listFeedback({ status = 'all' }) {
  const conditions = [];
  const params = [];

  if (status && status !== 'all') {
    params.push(status);
    conditions.push(`status = $${params.length}`);
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const res = await query(
    `SELECT f.*, u.name as user_name, u.email as user_email
     FROM feedback_submissions f
     LEFT JOIN users u ON u.id = f.user_id
     ${where}
     ORDER BY f.created_at DESC
     LIMIT 200`,
    params,
  );

  return res.rows;
}

async function updateFeedbackStatus({ feedbackId, status, adminNotes }) {
  const res = await query(
    `UPDATE feedback_submissions
     SET status = $2,
         admin_notes = coalesce($3, admin_notes),
         updated_at = now()
     WHERE id = $1
     RETURNING *`,
    [feedbackId, status, adminNotes || null],
  );

  if (!res.rows[0]) throw ApiError.notFound('Feedback not found');
  return res.rows[0];
}

async function getAuditLogs({ limit = 50, offset = 0 }) {
  const res = await query(
    `SELECT l.*, c.name as company_name, u.name as target_user_name,
            a.name as actor_name, a.email as actor_email
     FROM license_audit_logs l
     LEFT JOIN companies c ON c.id = l.company_id
     LEFT JOIN users u ON u.id = l.user_id
     LEFT JOIN users a ON a.id = l.actor_id
     ORDER BY l.created_at DESC
     LIMIT $1 OFFSET $2`,
    [limit, offset],
  );

  return res.rows;
}

module.exports = {
  adminLogin,
  getOverviewMetrics,
  listUsers,
  grantLifetimeLicense,
  grantTemporaryLicense,
  extendTemporaryLicense,
  setAccountSuspension,
  reviewAccountApproval,
  listManualPayments,
  decideManualPayment,
  listSupportMessages,
  updateSupportStatus,
  listFeedback,
  updateFeedbackStatus,
  getAuditLogs,
};

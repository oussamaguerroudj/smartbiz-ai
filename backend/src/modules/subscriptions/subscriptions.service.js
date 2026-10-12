const { query, withTransaction } = require('../../config/db');
const subscriptionConfig = require('../../config/subscription');
const ApiError = require('../../utils/ApiError');
const { processTrialReminders } = require('../notifications/reminders.service');

/**
 * Calculates current active/expired status and days remaining
 * based strictly on authoritative server timestamps in UTC.
 */
function evaluateEntitlement(company) {
  const now = new Date();
  const isSuspended = company.is_suspended === true;
  const isApproved = company.account_approval_status === 'approved';
  const type = company.entitlement_type || 'none';

  let hasAccess = false;
  let status = 'none'; // 'lifetime', 'active_trial', 'expired_trial', 'active_temporary', 'expired_temporary', 'pending_approval', 'suspended', 'none'
  let daysRemaining = null;
  let expiresAt = null;

  if (isSuspended) {
    status = 'suspended';
    hasAccess = false;
  } else if (!isApproved) {
    status = 'pending_approval';
    hasAccess = false;
  } else if (type === 'lifetime') {
    status = 'lifetime';
    hasAccess = true;
  } else if (type === 'trial') {
    if (company.trial_ends_at && new Date(company.trial_ends_at) > now) {
      status = 'active_trial';
      hasAccess = true;
      expiresAt = company.trial_ends_at;
      const diffMs = new Date(company.trial_ends_at).getTime() - now.getTime();
      daysRemaining = Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
    } else {
      status = 'expired_trial';
      hasAccess = false;
      expiresAt = company.trial_ends_at;
      daysRemaining = 0;
    }
  } else if (type === 'temporary') {
    if (company.license_expires_at && new Date(company.license_expires_at) > now) {
      status = 'active_temporary';
      hasAccess = true;
      expiresAt = company.license_expires_at;
      const diffMs = new Date(company.license_expires_at).getTime() - now.getTime();
      daysRemaining = Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
    } else {
      status = 'expired_temporary';
      hasAccess = false;
      expiresAt = company.license_expires_at;
      daysRemaining = 0;
    }
  } else {
    status = 'none';
    hasAccess = false;
  }

  return {
    hasAccess,
    status,
    entitlementType: type,
    daysRemaining,
    expiresAt,
    isSuspended,
    suspensionReason: company.suspension_reason || null,
    approvalStatus: company.account_approval_status || 'approved',
    trialStartsAt: company.trial_starts_at || null,
    trialEndsAt: company.trial_ends_at || null,
    licenseExpiresAt: company.license_expires_at || null,
  };
}

async function getEntitlementStatus(companyId) {
  // Fire reminder check opportunistically without blocking
  processTrialReminders().catch(() => {});

  const res = await query(
    `SELECT id, name, entitlement_type, trial_starts_at, trial_ends_at,
            license_expires_at, entitlement_granted_at, account_approval_status,
            is_suspended, suspension_reason
     FROM companies
     WHERE id = $1`,
    [companyId],
  );

  const company = res.rows[0];
  if (!company) {
    throw ApiError.notFound('Company record not found');
  }

  const evaluation = evaluateEntitlement(company);

  return {
    companyId: company.id,
    companyName: company.name,
    ...evaluation,
    product: {
      name: subscriptionConfig.product.licenseName,
      nameAr: subscriptionConfig.product.licenseNameAr,
      nameFr: subscriptionConfig.product.licenseNameFr,
      price: subscriptionConfig.product.priceDzd,
      currency: subscriptionConfig.product.currency,
      trialDurationDays: subscriptionConfig.product.trialDurationDays,
    },
    businessContact: {
      ownerName: subscriptionConfig.business.ownerName,
      ownerNameAr: subscriptionConfig.business.ownerNameAr,
      supportWhatsApp: subscriptionConfig.business.supportWhatsApp,
      whatsappUrl: subscriptionConfig.business.whatsappUrl,
      supportEmail: subscriptionConfig.business.supportEmail,
      ccpAccount: subscriptionConfig.business.ccpAccount,
      address: subscriptionConfig.business.address,
    },
  };
}

/**
 * Activates the 15-day free trial on the server.
 * Idempotent: repeated taps will not extend the expiration date or create multiple trials.
 */
async function selectFreeTrial(companyId, userId) {
  return withTransaction(async (client) => {
    const res = await client.query(
      `SELECT id, entitlement_type, trial_starts_at, trial_ends_at,
              license_expires_at, account_approval_status, is_suspended, suspension_reason
       FROM companies
       WHERE id = $1
       FOR UPDATE`,
      [companyId],
    );

    const company = res.rows[0];
    if (!company) {
      throw ApiError.notFound('Company record not found');
    }

    if (company.is_suspended) {
      throw ApiError.forbidden(
        'Account is suspended. Please contact support.',
        'ACCOUNT_SUSPENDED',
      );
    }

    if (company.entitlement_type === 'lifetime') {
      return evaluateEntitlement(company);
    }

    // If trial was already started, do not restart or extend it!
    if (company.trial_starts_at) {
      return evaluateEntitlement(company);
    }

    const trialDays = subscriptionConfig.product.trialDurationDays || 15;
    const now = new Date();
    const trialEnds = new Date(now.getTime() + trialDays * 24 * 60 * 60 * 1000);

    const updateRes = await client.query(
      `UPDATE companies
       SET entitlement_type = 'trial',
           trial_starts_at = $2,
           trial_ends_at = $3,
           updated_at = now()
       WHERE id = $1
       RETURNING *`,
      [companyId, now, trialEnds],
    );

    const updatedCompany = updateRes.rows[0];

    // Record audit event
    await client.query(
      `INSERT INTO license_audit_logs (
         company_id, user_id, actor_id, action, previous_entitlement,
         new_entitlement, new_expires_at, reason
       ) VALUES ($1, $2, $2, 'start_free_trial', 'none', 'trial', $3, 'User selected free trial during onboarding')`,
      [companyId, userId, trialEnds],
    );

    // Create welcoming in-app notification
    await client.query(
      `INSERT INTO notifications (company_id, user_id, type, title, body)
       VALUES ($1, $2, 'expiration_warning', $3, $4)`,
      [
        companyId,
        userId,
        'Welcome to Modiri AI Free Trial | مرحباً بك في التجربة المجانية',
        `Your 15-day free trial is now active until ${trialEnds.toISOString().split('T')[0]}. Enjoy all features of Modiri AI!`,
      ],
    );

    return evaluateEntitlement(updatedCompany);
  });
}

function getLifetimeProduct() {
  return {
    id: 'lifetime_license',
    name: subscriptionConfig.product.licenseName,
    nameAr: subscriptionConfig.product.licenseNameAr,
    nameFr: subscriptionConfig.product.licenseNameFr,
    price: subscriptionConfig.product.priceDzd,
    currency: subscriptionConfig.product.currency,
    trialDays: subscriptionConfig.product.trialDurationDays,
    paymentMethods: ['chargily', 'manual_ccp'],
    business: {
      ownerName: subscriptionConfig.business.ownerName,
      ownerNameAr: subscriptionConfig.business.ownerNameAr,
      supportEmail: subscriptionConfig.business.supportEmail,
      supportWhatsApp: subscriptionConfig.business.supportWhatsApp,
      whatsappUrl: subscriptionConfig.business.whatsappUrl,
      ccpAccount: subscriptionConfig.business.ccpAccount,
      address: subscriptionConfig.business.address,
    },
  };
}

module.exports = {
  getEntitlementStatus,
  selectFreeTrial,
  getLifetimeProduct,
  evaluateEntitlement,
};

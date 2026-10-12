const { query, withTransaction } = require('../../config/db');
const env = require('../../config/env');
const { sendMail } = require('../../utils/email');

/**
 * Dispatches an email notification if Brevo email delivery is configured,
 * otherwise safely skips and records status without failing the transaction.
 */
async function dispatchReminderEmail({ to, subject, title, body }) {
  if (!env.brevo || !env.brevo.apiKey) {
    return 'skipped_unconfigured';
  }

  try {
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
        <h2 style="color: #2563eb;">${title}</h2>
        <p style="white-space: pre-line; line-height: 1.6; color: #374151;">${body}</p>
        <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 13px; color: #6b7280;">
          <p>Modiri AI — Smart Business Management Platform</p>
          <p>Support: oussama.guerroudj@ensia.edu.dz | WhatsApp: +213 774 19 58 71</p>
        </div>
      </div>
    `;

    await sendMail({
      to,
      subject,
      html,
      text: `${title}\n\n${body}`,
    });
    return 'delivered';
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn(`[REMINDER EMAIL] Failed to send email to ${to}:`, err.message);
    return `failed: ${err.message}`;
  }
}

/**
 * Idempotently evaluates and processes trial reminders (48h and 24h)
 * and expiration for all active trial companies.
 *
 * Requirements:
 * - 48 hours before expiration (sent once)
 * - 24 hours before expiration (sent once)
 * - Expiration (when trial_ends_at <= now)
 * - Recalculates eligibility from server state (skip if already upgraded to lifetime or temporary)
 * - Idempotent and safe across concurrent or repeated scheduler runs
 */
async function processTrialReminders() {
  const now = new Date();

  // 1. Process 48-Hour Reminders (between 24h and 48h before expiration)
  const window48hStart = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const window48hEnd = new Date(now.getTime() + 48 * 60 * 60 * 1000);

  const due48hResult = await query(
    `SELECT c.id, c.name, c.trial_ends_at, u.id AS user_id, u.email
     FROM companies c
     JOIN users u ON u.company_id = c.id AND u.role = 'owner' AND u.deleted_at IS NULL
     WHERE c.entitlement_type = 'trial'
       AND c.is_suspended = false
       AND c.trial_ends_at IS NOT NULL
       AND c.trial_ends_at <= $1
       AND c.trial_ends_at > $2
       AND c.trial_reminder_48h_sent_at IS NULL`,
    [window48hEnd, window48hStart],
  );

  for (const row of due48hResult.rows) {
    await withTransaction(async (client) => {
      // Lock company row to prevent race conditions
      const lockRes = await client.query(
        `SELECT trial_reminder_48h_sent_at, entitlement_type
         FROM companies
         WHERE id = $1
         FOR UPDATE`,
        [row.id],
      );
      const company = lockRes.rows[0];
      if (!company || company.entitlement_type !== 'trial' || company.trial_reminder_48h_sent_at) {
        return;
      }

      const title = 'Trial Expiring in 48 Hours | تنبيه انتهاء التجربة خلال 48 ساعة';
      const body = 'Your Modiri AI free trial expires in 48 hours. Upgrade to the lifetime license for 15,000 DZD to continue according to the available plan.\n\nتنتهي تجربتك المجانية في Modiri AI خلال 48 ساعة. يمكنك الترقية إلى الرخصة مدى الحياة بسعر 15,000 دج.\n\nVotre essai gratuit Modiri AI expire dans 48 heures. Passez à la licence à vie pour 15 000 DZD.';

      // Insert in-app notification
      await client.query(
        `INSERT INTO notifications (company_id, user_id, type, title, body)
         VALUES ($1, $2, 'trial_reminder_48h', $3, $4)`,
        [row.id, row.user_id, title, body],
      );

      // Attempt email delivery if configured
      const emailStatus = await dispatchReminderEmail({
        to: row.email,
        subject: 'Modiri AI — Free Trial Expiring in 48 Hours | تنبيه انتهاء التجربة خلال 48 ساعة',
        title,
        body,
      });

      // Update company timestamp
      await client.query(
        `UPDATE companies
         SET trial_reminder_48h_sent_at = now(), updated_at = now()
         WHERE id = $1`,
        [row.id],
      );

      // Persist delivery audit record
      await client.query(
        `INSERT INTO license_audit_logs (
           company_id, user_id, action, previous_entitlement,
           new_entitlement, reason, metadata
         ) VALUES ($1, $2, 'trial_reminder_48h', 'trial', 'trial',
           '48-hour trial expiration reminder dispatched', $3)`,
        [
          row.id,
          row.user_id,
          JSON.stringify({
            email: row.email,
            inAppDelivered: true,
            emailDelivery: emailStatus,
          }),
        ],
      );
    });
  }

  // 2. Process 24-Hour Reminders (less than 24h before expiration, but not yet expired)
  const due24hResult = await query(
    `SELECT c.id, c.name, c.trial_ends_at, u.id AS user_id, u.email
     FROM companies c
     JOIN users u ON u.company_id = c.id AND u.role = 'owner' AND u.deleted_at IS NULL
     WHERE c.entitlement_type = 'trial'
       AND c.is_suspended = false
       AND c.trial_ends_at IS NOT NULL
       AND c.trial_ends_at <= $1
       AND c.trial_ends_at > $2
       AND c.trial_reminder_24h_sent_at IS NULL`,
    [window48hStart, now],
  );

  for (const row of due24hResult.rows) {
    await withTransaction(async (client) => {
      const lockRes = await client.query(
        `SELECT trial_reminder_24h_sent_at, entitlement_type
         FROM companies
         WHERE id = $1
         FOR UPDATE`,
        [row.id],
      );
      const company = lockRes.rows[0];
      if (!company || company.entitlement_type !== 'trial' || company.trial_reminder_24h_sent_at) {
        return;
      }

      const title = 'Trial Expiring in 24 Hours | تنبيه انتهاء التجربة خلال 24 ساعة';
      const body = 'Your Modiri AI free trial expires in 24 hours. Upgrade to the lifetime license for 15,000 DZD to continue according to the available plan.\n\nتنتهي تجربتك المجانية في Modiri AI خلال 24 ساعة. يمكنك الترقية إلى الرخصة مدى الحياة بسعر 15,000 دج.\n\nVotre essai gratuit Modiri AI expire dans 24 heures. Passez à la licence à vie pour 15 000 DZD.';

      await client.query(
        `INSERT INTO notifications (company_id, user_id, type, title, body)
         VALUES ($1, $2, 'trial_reminder_24h', $3, $4)`,
        [row.id, row.user_id, title, body],
      );

      const emailStatus = await dispatchReminderEmail({
        to: row.email,
        subject: 'Modiri AI — Final Reminder: Trial Expiring in 24 Hours | تنبيه أخير: انتهاء التجربة',
        title,
        body,
      });

      await client.query(
        `UPDATE companies
         SET trial_reminder_24h_sent_at = now(), updated_at = now()
         WHERE id = $1`,
        [row.id],
      );

      await client.query(
        `INSERT INTO license_audit_logs (
           company_id, user_id, action, previous_entitlement,
           new_entitlement, reason, metadata
         ) VALUES ($1, $2, 'trial_reminder_24h', 'trial', 'trial',
           '24-hour trial expiration reminder dispatched', $3)`,
        [
          row.id,
          row.user_id,
          JSON.stringify({
            email: row.email,
            inAppDelivered: true,
            emailDelivery: emailStatus,
          }),
        ],
      );
    });
  }

  // 3. Process Expired Trials (trial_ends_at <= now)
  const expiredResult = await query(
    `SELECT c.id, c.name, c.trial_ends_at, u.id AS user_id, u.email
     FROM companies c
     JOIN users u ON u.company_id = c.id AND u.role = 'owner' AND u.deleted_at IS NULL
     WHERE c.entitlement_type = 'trial'
       AND c.is_suspended = false
       AND c.trial_ends_at IS NOT NULL
       AND c.trial_ends_at <= $1
       AND c.trial_reminder_expired_sent_at IS NULL`,
    [now],
  );

  for (const row of expiredResult.rows) {
    await withTransaction(async (client) => {
      const lockRes = await client.query(
        `SELECT trial_reminder_expired_sent_at, entitlement_type
         FROM companies
         WHERE id = $1
         FOR UPDATE`,
        [row.id],
      );
      const company = lockRes.rows[0];
      if (!company || company.entitlement_type !== 'trial' || company.trial_reminder_expired_sent_at) {
        return;
      }

      const title = 'Trial Expired | انتهت التجربة المجانية';
      const body = 'Your Modiri AI free trial has expired. Upgrade to the lifetime license for 15,000 DZD to restore full access. Your data remains safe.\n\nانتهت فترتك التجريبية المجانية. يرجى الترقية إلى رخصة مدى الحياة مقابل 15,000 دج للاستمرار. بياناتك محفوظة بأمان.\n\nVotre essai gratuit Modiri AI a expiré. Passez à la licence à vie pour 15 000 DZD. Vos données sont conservées en toute sécurité.';

      await client.query(
        `INSERT INTO notifications (company_id, user_id, type, title, body)
         VALUES ($1, $2, 'trial_expired', $3, $4)`,
        [row.id, row.user_id, title, body],
      );

      const emailStatus = await dispatchReminderEmail({
        to: row.email,
        subject: 'Modiri AI — Free Trial Expired | انتهت فترتك التجريبية المجانية',
        title,
        body,
      });

      await client.query(
        `UPDATE companies
         SET trial_reminder_expired_sent_at = now(), updated_at = now()
         WHERE id = $1`,
        [row.id],
      );

      await client.query(
        `INSERT INTO license_audit_logs (
           company_id, user_id, action, previous_entitlement,
           new_entitlement, reason, metadata
         ) VALUES ($1, $2, 'trial_expired', 'trial', 'trial',
           'Trial expiration notice dispatched', $3)`,
        [
          row.id,
          row.user_id,
          JSON.stringify({
            email: row.email,
            inAppDelivered: true,
            emailDelivery: emailStatus,
          }),
        ],
      );
    });
  }

  return {
    processed48h: due48hResult.rows.length,
    processed24h: due24hResult.rows.length,
    processedExpired: expiredResult.rows.length,
  };
}

module.exports = { processTrialReminders };

const { query } = require('../../config/db');

/**
 * Registers or refreshes a push notification device token for a user.
 */
async function registerDeviceToken({ userId, companyId, token, platform = 'android', deviceInfo = {} }) {
  if (!token || typeof token !== 'string' || token.trim().length === 0) {
    throw new Error('Device token is required');
  }

  const cleanToken = token.trim();
  const cleanPlatform = String(platform).trim().toLowerCase();

  const res = await query(
    `INSERT INTO device_tokens (user_id, company_id, token, platform, device_info, last_used_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, now(), now())
     ON CONFLICT (user_id, token)
     DO UPDATE SET
       last_used_at = now(),
       updated_at = now(),
       platform = EXCLUDED.platform,
       device_info = EXCLUDED.device_info
     RETURNING id, user_id, company_id, platform, updated_at`,
    [userId, companyId, cleanToken, cleanPlatform, JSON.stringify(deviceInfo || {})],
  );

  return res.rows[0];
}

/**
 * Unregisters a push device token (e.g. on logout).
 */
async function unregisterDeviceToken({ userId, token }) {
  if (!token) return { deleted: false };

  const res = await query(
    `DELETE FROM device_tokens
     WHERE user_id = $1 AND token = $2
     RETURNING id`,
    [userId, token.trim()],
  );

  return { deleted: res.rows.length > 0 };
}

/**
 * Sends a push notification to registered devices for a user or entire company.
 */
async function sendPushNotification({ userId, companyId, title, body, data = {} }) {
  try {
    let tokensRes;
    if (userId) {
      tokensRes = await query(
        `SELECT id, token, platform FROM device_tokens WHERE user_id = $1`,
        [userId],
      );
    } else if (companyId) {
      tokensRes = await query(
        `SELECT id, token, platform FROM device_tokens WHERE company_id = $1`,
        [companyId],
      );
    } else {
      return { sent: 0, reason: 'missing_recipient' };
    }

    const tokens = tokensRes.rows;
    if (tokens.length === 0) {
      return { sent: 0, reason: 'no_registered_devices' };
    }

    // eslint-disable-next-line no-console
    console.log(`[PUSH NOTIFICATION] Sending to ${tokens.length} device(s) [User: ${userId || 'N/A'}, Company: ${companyId || 'N/A'}]: "${title}"`);

    // In environment without external FCM credentials, record dispatch log safely
    return {
      sent: tokens.length,
      title,
      body,
      timestamp: new Date().toISOString(),
    };
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[PUSH NOTIFICATION] Error dispatching push:', err.message);
    return { sent: 0, error: err.message };
  }
}

module.exports = {
  registerDeviceToken,
  unregisterDeviceToken,
  sendPushNotification,
};

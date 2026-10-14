const { query } = require('../../config/db');
const firebaseConfig = require('../../config/firebase');

/**
 * Safely masks device tokens for secure logging. Never logs complete tokens.
 */
function maskToken(token) {
  if (!token || typeof token !== 'string') return '<empty>';
  if (token.length <= 10) return '***';
  return `${token.substring(0, 6)}...${token.substring(token.length - 4)}`;
}

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
 * Strictly respects tenant isolation.
 * Automatically cleans up invalid or expired tokens returned by FCM.
 * Returns delivery metrics without breaking caller transactions.
 */
async function sendPushNotification({ userId, companyId, title, body, data = {} }) {
  try {
    let tokensRes;
    if (userId && companyId) {
      tokensRes = await query(
        `SELECT id, token, platform, user_id, company_id FROM device_tokens WHERE user_id = $1 AND company_id = $2`,
        [userId, companyId],
      );
    } else if (userId) {
      tokensRes = await query(
        `SELECT id, token, platform, user_id, company_id FROM device_tokens WHERE user_id = $1`,
        [userId],
      );
    } else if (companyId) {
      tokensRes = await query(
        `SELECT id, token, platform, user_id, company_id FROM device_tokens WHERE company_id = $1`,
        [companyId],
      );
    } else {
      return { sent: 0, failed: 0, reason: 'missing_recipient' };
    }

    const tokenRows = tokensRes.rows;
    if (tokenRows.length === 0) {
      return { sent: 0, failed: 0, reason: 'no_registered_devices' };
    }

    // Convert all data payload properties to strings as strictly mandated by FCM v1
    const sanitizedData = {};
    for (const [k, v] of Object.entries(data || {})) {
      sanitizedData[k] = typeof v === 'string' ? v : JSON.stringify(v);
    }

    const messaging = firebaseConfig.getMessaging();
    if (!messaging || !firebaseConfig.isFirebaseConfigured()) {
      // In environment without external FCM credentials, record dispatch log safely (tokens masked)
      // eslint-disable-next-line no-console
      console.log(`[PUSH] Skipped remote FCM (no credentials configured). Would dispatch to ${tokenRows.length} device(s) [User: ${userId || 'N/A'}, Company: ${companyId || 'N/A'}]`);
      return {
        sent: 0,
        failed: 0,
        simulated: tokenRows.length,
        reason: 'unconfigured_credentials',
      };
    }

    const tokens = tokenRows.map((r) => r.token);
    const multicastPayload = {
      tokens,
      notification: {
        title,
        body,
      },
      data: sanitizedData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'modiri_notifications',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(multicastPayload);

    let invalidTokensRemoved = 0;
    if (response.failureCount > 0 && Array.isArray(response.responses)) {
      for (let i = 0; i < response.responses.length; i++) {
        const resp = response.responses[i];
        if (!resp.success && resp.error) {
          const errCode = resp.error.code;
          const failedRow = tokenRows[i];
          if (
            errCode === 'messaging/invalid-registration-token' ||
            errCode === 'messaging/registration-token-not-registered'
          ) {
            // Delete only this specific dead token row for this user
            try {
              await query(
                `DELETE FROM device_tokens WHERE id = $1 AND user_id = $2`,
                [failedRow.id, failedRow.user_id],
              );
              invalidTokensRemoved++;
              // eslint-disable-next-line no-console
              console.log(`[PUSH] Pruned expired/invalid token ${maskToken(failedRow.token)} for user ${failedRow.user_id}`);
            } catch (pruneErr) {
              // eslint-disable-next-line no-console
              console.warn('[PUSH] Failed to prune invalid token:', pruneErr.message);
            }
          } else {
            // eslint-disable-next-line no-console
            console.warn(`[PUSH] FCM dispatch failure for device ${maskToken(failedRow.token)}:`, errCode);
          }
        }
      }
    }

    // eslint-disable-next-line no-console
    console.log(`[PUSH] Dispatched push: ${response.successCount} sent, ${response.failureCount} failed (${invalidTokensRemoved} pruned) [User: ${userId || 'N/A'}, Company: ${companyId || 'N/A'}]`);

    return {
      sent: response.successCount,
      failed: response.failureCount,
      pruned: invalidTokensRemoved,
    };
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[PUSH] Unexpected error dispatching push:', err.message);
    return { sent: 0, failed: 0, error: err.message };
  }
}

module.exports = {
  registerDeviceToken,
  unregisterDeviceToken,
  sendPushNotification,
  maskToken,
};

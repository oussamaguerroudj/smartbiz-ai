const admin = require('firebase-admin');

let initialized = false;
let isConfigured = false;

function initFirebase() {
  if (initialized) return admin;
  initialized = true;

  const apps = typeof admin.getApps === 'function' ? admin.getApps() : (admin.apps || []);
  if (apps.length > 0) {
    isConfigured = true;
    return admin;
  }

  // 1. Google Application Credentials via file path
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    try {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
      isConfigured = true;
      // eslint-disable-next-line no-console
      console.log('[FIREBASE] Initialized with Google Application Default Credentials');
      return admin;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[FIREBASE] Failed to initialize with GOOGLE_APPLICATION_CREDENTIALS:', err.message);
    }
  }

  // 2. Secret environment variable (Render, Heroku, etc.)
  const rawSecret = process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (rawSecret && typeof rawSecret === 'string' && rawSecret.trim().length > 0) {
    try {
      let certObj;
      const trimmed = rawSecret.trim();
      if (trimmed.startsWith('{')) {
        certObj = JSON.parse(trimmed);
      } else {
        // Try base64 decoding
        const decoded = Buffer.from(trimmed, 'base64').toString('utf8');
        certObj = JSON.parse(decoded);
      }

      admin.initializeApp({
        credential: admin.credential.cert(certObj),
      });
      isConfigured = true;
      // eslint-disable-next-line no-console
      console.log('[FIREBASE] Initialized with FIREBASE_SERVICE_ACCOUNT credentials');
      return admin;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('[FIREBASE] Failed to parse FIREBASE_SERVICE_ACCOUNT:', err.message);
    }
  }

  // eslint-disable-next-line no-console
  console.log('[FIREBASE] No Firebase Admin credentials found in environment. Remote FCM dispatches will run in unconfigured mode.');
  return admin;
}

function getFirebaseAdmin() {
  return initFirebase();
}

function isConfiguredCheck() {
  if (!initialized) initFirebase();
  const apps = typeof admin.getApps === 'function' ? admin.getApps() : (admin.apps || []);
  return isConfigured && apps.length > 0;
}

function getMessaging() {
  initFirebase();
  if (!isConfiguredCheck()) return null;
  return admin.messaging();
}

/**
 * Resets Firebase Admin state (useful in test suites)
 */
function _resetForTesting({ configured = false, customAdmin = null } = {}) {
  initialized = true;
  isConfigured = configured;
  if (customAdmin) {
    return customAdmin;
  }
}

module.exports = {
  getFirebaseAdmin,
  isFirebaseConfigured: isConfiguredCheck,
  getMessaging,
  _resetForTesting,
};

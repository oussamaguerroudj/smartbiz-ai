const crypto = require('crypto');

/** A random 6-digit numeric code, e.g. "042817" (zero-padded). */
function generateCode() {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

/**
 * One-way hash for storing a code server-side. Uses SHA-256 (not
 * bcrypt) deliberately — these codes are short-lived (minutes) and
 * low-entropy by design (6 digits), so bcrypt's slow-hashing property
 * buys nothing here and just slows down every verify request; SHA-256
 * is fine given the short expiry + attempt-count limiting done by the
 * caller.
 */
function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

module.exports = { generateCode, hashCode };

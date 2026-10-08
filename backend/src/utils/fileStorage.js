const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// This project has no cloud object storage (S3/GCS/etc.) wired up, and
// the rest of the app's only precedent for sending binary content to
// the backend is base64-in-JSON (ai.service.js's invoice-scan photo,
// see app.js's body-limit comment) — not multipart/form-data. This
// module follows that same precedent rather than introducing a second,
// inconsistent upload mechanism: it decodes a base64 payload and writes
// it to local disk, under a directory that is NEVER mounted as static
// (see app.js — no express.static call anywhere), so every read goes
// through the authenticated, company-scoped download route in
// clinic.routes.js instead of a guessable public URL.
const STORAGE_ROOT = process.env.FILE_STORAGE_ROOT
  ? path.resolve(process.env.FILE_STORAGE_ROOT)
  : path.join(__dirname, '..', '..', 'storage');

const MIME_EXTENSIONS = {
  'application/pdf': '.pdf',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

/**
 * Verifies the file's leading magic bytes match its declared MIME type
 * so disguised executables, HTML/SVG XSS payloads, or polyglot files
 * cannot be uploaded by spoofing `mimeType`.
 */
function hasValidMagicBytes(mimeType, buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4) {
    return false;
  }
  switch (mimeType) {
    case 'application/pdf':
      // %PDF- (25 50 44 46 2D)
      return (
        buffer.length >= 5 &&
        buffer[0] === 0x25 &&
        buffer[1] === 0x50 &&
        buffer[2] === 0x44 &&
        buffer[3] === 0x46 &&
        buffer[4] === 0x2d
      );
    case 'image/jpeg':
      // FF D8 FF
      return buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
    case 'image/png':
      // 89 50 4E 47 0D 0A 1A 0A
      return (
        buffer.length >= 8 &&
        buffer[0] === 0x89 &&
        buffer[1] === 0x50 &&
        buffer[2] === 0x4e &&
        buffer[3] === 0x47 &&
        buffer[4] === 0x0d &&
        buffer[5] === 0x0a &&
        buffer[6] === 0x1a &&
        buffer[7] === 0x0a
      );
    case 'image/webp':
      // RIFF....WEBP
      return (
        buffer.length >= 12 &&
        buffer.toString('ascii', 0, 4) === 'RIFF' &&
        buffer.toString('ascii', 8, 12) === 'WEBP'
      );
    default:
      return false;
  }
}

/**
 * Decodes and writes a base64 payload under STORAGE_ROOT/<namespace>/<companyId>/.
 * Returns the RELATIVE storage key (not a URL — never handed to a
 * client directly) and the real decoded byte size, which is what gets
 * persisted as file_size (never trust a client-supplied size).
 *
 * Throws a plain Error with a `.code` the caller can map to a friendly
 * ApiError — kept storage-concern-only here, no HTTP knowledge.
 */
function saveBase64File({ namespace, companyId, originalName, mimeType, base64Data, maxBytes }) {
  if (!MIME_EXTENSIONS[mimeType]) {
    const err = new Error(`Unsupported file type: ${mimeType}`);
    err.code = 'UNSUPPORTED_FILE_TYPE';
    throw err;
  }

  if (typeof base64Data !== 'string' || base64Data.trim().length === 0) {
    const err = new Error('Invalid base64 file data');
    err.code = 'INVALID_FILE_DATA';
    throw err;
  }

  // Strip optional data URI prefix if present
  const rawBase64 = base64Data.replace(/^data:[^;]+;base64,/, '').trim();

  let buffer;
  try {
    buffer = Buffer.from(rawBase64, 'base64');
  } catch {
    const err = new Error('Invalid base64 file data');
    err.code = 'INVALID_FILE_DATA';
    throw err;
  }

  if (buffer.length === 0) {
    const err = new Error('Invalid base64 file data');
    err.code = 'INVALID_FILE_DATA';
    throw err;
  }

  if (maxBytes && buffer.length > maxBytes) {
    const err = new Error(`File exceeds the maximum allowed size of ${maxBytes} bytes`);
    err.code = 'FILE_TOO_LARGE';
    throw err;
  }

  if (!hasValidMagicBytes(mimeType, buffer)) {
    const err = new Error('File content does not match declared MIME type');
    err.code = 'INVALID_FILE_DATA';
    throw err;
  }

  const dir = path.join(STORAGE_ROOT, namespace, companyId);
  fs.mkdirSync(dir, { recursive: true });

  const safeName = `${crypto.randomUUID()}${MIME_EXTENSIONS[mimeType]}`;
  const absolutePath = path.join(dir, safeName);
  fs.writeFileSync(absolutePath, buffer);

  return {
    storageKey: path.posix.join(namespace, companyId, safeName),
    fileSize: buffer.length,
  };
}

/** Resolves a storage key back to an absolute path, refusing anything
 * that would escape STORAGE_ROOT or traverse across namespaces/tenants. */
function resolveStoragePath(storageKey) {
  if (
    typeof storageKey !== 'string' ||
    storageKey.length === 0 ||
    storageKey.includes('\0') ||
    storageKey.includes('..') ||
    storageKey.includes('\\') ||
    storageKey.startsWith('/')
  ) {
    const err = new Error('Invalid storage key');
    err.code = 'INVALID_STORAGE_KEY';
    throw err;
  }
  const rootResolved = path.resolve(STORAGE_ROOT);
  const absolute = path.resolve(rootResolved, storageKey);
  const rootWithSep = rootResolved.endsWith(path.sep) ? rootResolved : rootResolved + path.sep;
  if (!absolute.startsWith(rootWithSep) && absolute !== rootResolved) {
    const err = new Error('Invalid storage key');
    err.code = 'INVALID_STORAGE_KEY';
    throw err;
  }
  return absolute;
}

module.exports = { saveBase64File, resolveStoragePath, hasValidMagicBytes, MIME_EXTENSIONS };

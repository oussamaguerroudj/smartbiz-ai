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

  let buffer;
  try {
    buffer = Buffer.from(base64Data, 'base64');
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
 * that would escape STORAGE_ROOT (defence in depth — storageKey always
 * comes from our own DB row, never directly from client input, but
 * this keeps the guarantee even if that ever changes). */
function resolveStoragePath(storageKey) {
  const absolute = path.join(STORAGE_ROOT, storageKey);
  if (!absolute.startsWith(STORAGE_ROOT)) {
    const err = new Error('Invalid storage key');
    err.code = 'INVALID_STORAGE_KEY';
    throw err;
  }
  return absolute;
}

module.exports = { saveBase64File, resolveStoragePath, MIME_EXTENSIONS };

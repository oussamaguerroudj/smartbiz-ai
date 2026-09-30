const express = require('express');
const fs = require('fs');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const fileStorage = require('../../utils/fileStorage');
const { authMiddleware } = require('../../middlewares/auth.middleware');

// Ch. 17 "Product Images — All Business Types": one shared upload/serve
// pair reused by every products/items table that gets an image_url
// column (products, restaurant_menu_items, restaurant_inventory_items,
// and any future one) instead of duplicating this per module — same
// base64-in-JSON-to-local-disk approach as clinic documents
// (fileStorage.js), just with a smaller size cap and a plain image-only
// allowlist (no PDF) since these are always photos.

const router = express.Router();
// router.use(authMiddleware) removed from top level so that <img src="..."> tags can stream images
const MAX_IMAGE_SIZE_BYTES = 4 * 1024 * 1024; // 4 MB decoded
const ALLOWED_NAMESPACES = new Set(['products', 'restaurant-menu', 'restaurant-inventory', 'avatars']);
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

const upload = asyncHandler(async (req, res) => {
  const { namespace, fileBase64, mimeType } = req.body || {};

  if (!ALLOWED_NAMESPACES.has(namespace)) {
    throw ApiError.badRequest(
      `namespace must be one of: ${[...ALLOWED_NAMESPACES].join(', ')}`,
      'VALIDATION_ERROR',
    );
  }
  if (typeof fileBase64 !== 'string' || !fileBase64) {
    throw ApiError.badRequest('fileBase64 is required', 'VALIDATION_ERROR');
  }
  if (!ALLOWED_IMAGE_TYPES.has(mimeType)) {
    throw ApiError.badRequest(
      'The uploaded file type is not supported. Allowed types: JPEG, PNG, WEBP.',
      'UNSUPPORTED_FILE_TYPE',
    );
  }

  let stored;
  try {
    stored = fileStorage.saveBase64File({
      namespace,
      companyId: req.user.companyId,
      originalName: 'image',
      mimeType,
      base64Data: fileBase64,
      maxBytes: MAX_IMAGE_SIZE_BYTES,
    });
  } catch (err) {
    if (err.code === 'FILE_TOO_LARGE') {
      throw ApiError.badRequest('The image is too large (max 4 MB)', 'FILE_TOO_LARGE');
    }
    if (err.code === 'UNSUPPORTED_FILE_TYPE' || err.code === 'INVALID_FILE_DATA') {
      throw ApiError.badRequest(err.message, err.code);
    }
    throw err;
  }

  res.status(201).json({ data: { imageUrl: stored.storageKey } });
});

/**
 * Serves an image by storage key.
 */
const file = asyncHandler(async (req, res) => {
  const key = req.query.key;
  if (typeof key !== 'string' || !key) {
    throw ApiError.badRequest('key is required', 'VALIDATION_ERROR');
  }

  const segments = key.split('/');
  const [namespace] = segments;
  if (!ALLOWED_NAMESPACES.has(namespace)) {
    throw ApiError.notFound('Image not found');
  }

  let absolutePath;
  try {
    absolutePath = fileStorage.resolveStoragePath(key);
  } catch {
    throw ApiError.notFound('Image not found');
  }
  if (!fs.existsSync(absolutePath)) {
    throw ApiError.notFound('Image not found');
  }

  const ext = absolutePath.split('.').pop();
  const mimeByExt = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };
  res.setHeader('Content-Type', mimeByExt[ext.toLowerCase()] || 'application/octet-stream');
  fs.createReadStream(absolutePath).pipe(res);
});

router.post('/', authMiddleware, upload);
router.get('/file', file);

module.exports = router;

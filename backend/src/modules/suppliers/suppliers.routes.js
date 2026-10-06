const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware } = require('../../middlewares/auth.middleware');

// Repository
async function findAll(companyId) {
  const result = await query(
    `SELECT s.*,
            COUNT(p.id)::int AS products_supplied
     FROM suppliers s
     LEFT JOIN products p
       ON p.supplier_id = s.id
      AND p.company_id = s.company_id
      AND p.deleted_at IS NULL
     WHERE s.company_id = $1
       AND s.deleted_at IS NULL
     GROUP BY s.id
     ORDER BY s.name ASC`,
    [companyId],
  );

  return result.rows;
}

async function create(
  companyId,
  {
    name,
    phone,
    address,
  },
) {
  const result = await query(
    `INSERT INTO suppliers
       (company_id, name, phone, address)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [
      companyId,
      name,
      phone || null,
      address || null,
    ],
  );

  return result.rows[0];
}

async function update(
  companyId,
  id,
  {
    name,
    phone,
    address,
  },
) {
  const result = await query(
    `UPDATE suppliers
     SET name = COALESCE($3, name),
         phone = COALESCE($4, phone),
         address = COALESCE($5, address),
         updated_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      id,
      name,
      phone,
      address,
    ],
  );

  return result.rows[0] || null;
}

async function softDelete(companyId, id) {
  const result = await query(
    `UPDATE suppliers
     SET deleted_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING id`,
    [companyId, id],
  );

  return result.rows[0] || null;
}

// Service
async function createSupplier(companyId, data = {}) {
  const {
    name,
    phone,
    address,
  } = data;

  if (
    typeof name !== 'string' ||
    name.trim().length < 2
  ) {
    throw ApiError.badRequest(
      'name must be at least 2 characters',
      'VALIDATION_ERROR',
    );
  }

  if (name.trim().length > 255) {
    throw ApiError.badRequest(
      'name must not exceed 255 characters',
      'VALIDATION_ERROR',
    );
  }

  if (
    phone !== undefined &&
    phone !== null &&
    (
      typeof phone !== 'string' ||
      phone.trim().length > 50
    )
  ) {
    throw ApiError.badRequest(
      'phone must be a string with at most 50 characters',
      'VALIDATION_ERROR',
    );
  }

  if (
    address !== undefined &&
    address !== null &&
    (
      typeof address !== 'string' ||
      address.trim().length > 500
    )
  ) {
    throw ApiError.badRequest(
      'address must be a string with at most 500 characters',
      'VALIDATION_ERROR',
    );
  }

  return create(companyId, {
    name: name.trim(),
    phone: typeof phone === 'string'
      ? phone.trim()
      : phone,
    address: typeof address === 'string'
      ? address.trim()
      : address,
  });
}

async function updateSupplier(companyId, id, data = {}) {
  const { name, phone, address } = data;

  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length < 2) {
      throw ApiError.badRequest('name must be at least 2 characters', 'VALIDATION_ERROR');
    }
    if (name.trim().length > 255) {
      throw ApiError.badRequest('name must not exceed 255 characters', 'VALIDATION_ERROR');
    }
  }

  const updated = await update(companyId, id, {
    name: typeof name === 'string' ? name.trim() : undefined,
    phone: typeof phone === 'string' ? phone.trim() : phone,
    address: typeof address === 'string' ? address.trim() : address,
  });

  if (!updated) {
    throw ApiError.notFound('Supplier not found');
  }

  return updated;
}

async function deleteSupplier(companyId, id) {
  const deleted = await softDelete(companyId, id);
  if (!deleted) {
    throw ApiError.notFound('Supplier not found');
  }
  return { id };
}

// Controller
const list = asyncHandler(async (req, res) => {
  res.json({
    data: await findAll(req.user.companyId),
  });
});

const createHandler = asyncHandler(async (req, res) => {
  const supplier = await createSupplier(
    req.user.companyId,
    req.body || {},
  );

  res.status(201).json({
    data: supplier,
  });
});

const updateHandler = asyncHandler(async (req, res) => {
  const supplier = await updateSupplier(
    req.user.companyId,
    req.params.id,
    req.body || {},
  );

  res.json({
    data: supplier,
  });
});

const deleteHandler = asyncHandler(async (req, res) => {
  const result = await deleteSupplier(
    req.user.companyId,
    req.params.id,
  );

  res.json({
    data: result,
  });
});

// Routes
const router = express.Router();

router.use(authMiddleware);

router.get('/', list);
router.post('/', createHandler);
router.put('/:id', updateHandler);
router.delete('/:id', deleteHandler);

router.createSupplier = createSupplier;
router.updateSupplier = updateSupplier;
router.deleteSupplier = deleteSupplier;

module.exports = router;
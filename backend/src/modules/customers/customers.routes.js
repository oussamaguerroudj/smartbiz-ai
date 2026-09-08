const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware } = require('../../middlewares/auth.middleware');

// Repository
async function findAll(companyId) {
  const result = await query(
    `SELECT *
     FROM customers
     WHERE company_id = $1
       AND deleted_at IS NULL
     ORDER BY name ASC`,
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
    `INSERT INTO customers
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

// Service
async function createCustomer(companyId, data = {}) {
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

// Controller
const list = asyncHandler(async (req, res) => {
  res.json({
    data: await findAll(req.user.companyId),
  });
});

const createHandler = asyncHandler(async (req, res) => {
  const customer = await createCustomer(
    req.user.companyId,
    req.body || {},
  );

  res.status(201).json({
    data: customer,
  });
});

// Routes
const router = express.Router();

router.use(authMiddleware);

router.get('/', list);
router.post('/', createHandler);

module.exports = router;
const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware } = require('../../middlewares/auth.middleware');

// Repository
async function findAll(companyId) {
  const result = await query(
    `SELECT * FROM customers WHERE company_id = $1 AND deleted_at IS NULL ORDER BY name ASC`,
    [companyId],
  );
  return result.rows;
}

async function create(companyId, { name, phone, address }) {
  const result = await query(
    `INSERT INTO customers (company_id, name, phone, address) VALUES ($1, $2, $3, $4) RETURNING *`,
    [companyId, name, phone || null, address || null],
  );
  return result.rows[0];
}

// Service
async function createCustomer(companyId, data) {
  if (!data.name || typeof data.name !== 'string' || data.name.trim().length < 1) {
    throw ApiError.badRequest('name is required', 'VALIDATION_ERROR');
  }
  return create(companyId, data);
}

// Controller
const list = asyncHandler(async (req, res) => {
  res.json({ data: await findAll(req.user.companyId) });
});

const createHandler = asyncHandler(async (req, res) => {
  res.status(201).json({ data: await createCustomer(req.user.companyId, req.body) });
});

// Routes
const router = express.Router();
router.use(authMiddleware);
router.get('/', list);
router.post('/', createHandler);

module.exports = router;

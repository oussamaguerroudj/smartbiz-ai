const express = require('express');
const { query } = require('../../config/db');
const asyncHandler = require('../../utils/asyncHandler');
const ApiError = require('../../utils/ApiError');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const purchasesService = require('./supplier_purchases.service');

// Repository
async function findAll(companyId) {
  const result = await query(
    `SELECT s.*,
            COALESCE(prod_agg.products_supplied, 0)::int AS products_supplied,
            COALESCE(purch_agg.outstanding_balance, 0)::numeric(15,2) AS outstanding_balance,
            COALESCE(purch_agg.total_purchases_amount, 0)::numeric(15,2) AS total_purchases_amount,
            COALESCE(purch_agg.total_purchases_paid, 0)::numeric(15,2) AS total_purchases_paid
     FROM suppliers s
     LEFT JOIN (
       SELECT supplier_id, COUNT(id) AS products_supplied
       FROM products
       WHERE company_id = $1 AND deleted_at IS NULL
       GROUP BY supplier_id
     ) prod_agg ON prod_agg.supplier_id = s.id
     LEFT JOIN (
       SELECT supplier_id,
              SUM(outstanding_balance) AS outstanding_balance,
              SUM(total_amount) AS total_purchases_amount,
              SUM(amount_paid) AS total_purchases_paid
       FROM supplier_purchases
       WHERE company_id = $1 AND deleted_at IS NULL
       GROUP BY supplier_id
     ) purch_agg ON purch_agg.supplier_id = s.id
     WHERE s.company_id = $1
       AND s.deleted_at IS NULL
     GROUP BY s.id, prod_agg.products_supplied, purch_agg.outstanding_balance, purch_agg.total_purchases_amount, purch_agg.total_purchases_paid
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

async function findById(companyId, id) {
  const supplierResult = await query(
    `SELECT s.*,
            COUNT(p.id)::int AS products_supplied
     FROM suppliers s
     LEFT JOIN products p
       ON p.supplier_id = s.id
      AND p.company_id = s.company_id
      AND p.deleted_at IS NULL
     WHERE s.company_id = $1
       AND s.id = $2
       AND s.deleted_at IS NULL
     GROUP BY s.id`,
    [companyId, id],
  );

  const supplier = supplierResult.rows[0];
  if (!supplier) {
    throw ApiError.notFound('Supplier not found');
  }

  const productsResult = await query(
    `SELECT id, name, category, barcode, purchase_price, selling_price, quantity, expiration_date
     FROM products
     WHERE company_id = $1
       AND supplier_id = $2
       AND deleted_at IS NULL
     ORDER BY name ASC`,
    [companyId, id],
  );

  const products = productsResult ? productsResult.rows || [] : [];
  const totalStockUnits = products.reduce((acc, p) => acc + (parseInt(p.quantity, 10) || 0), 0);
  const totalPurchaseValue = products.reduce(
    (acc, p) => acc + ((parseFloat(p.purchase_price) || 0) * (parseInt(p.quantity, 10) || 0)),
    0,
  );

  let apBalance = {
    total_purchases_amount: 0,
    total_purchases_paid: 0,
    outstanding_balance: 0,
    purchases_count: 0,
    payments_count: 0,
    total_payments_recorded: 0,
  };

  try {
    const bal = await purchasesService.getSupplierBalance(companyId, id);
    if (bal) apBalance = bal;
  } catch (_) {}

  return {
    ...supplier,
    total_stock_units: totalStockUnits,
    total_purchase_value: totalPurchaseValue,
    total_assigned_inventory_valuation: totalPurchaseValue,
    total_purchases_amount: apBalance.total_purchases_amount,
    total_purchases_paid: apBalance.total_purchases_paid,
    outstanding_balance: apBalance.outstanding_balance,
    purchases_count: apBalance.purchases_count,
    payments_count: apBalance.payments_count,
    total_payments_recorded: apBalance.total_payments_recorded,
    products,
  };
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

const getByIdHandler = asyncHandler(async (req, res) => {
  const data = await findById(
    req.user.companyId,
    req.params.id,
  );

  res.json({
    data,
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

const getPurchasesHandler = asyncHandler(async (req, res) => {
  const purchases = await purchasesService.getSupplierPurchases(
    req.user.companyId,
    req.params.id,
  );
  res.json({
    data: purchases,
  });
});

const createPurchaseHandler = asyncHandler(async (req, res) => {
  const result = await purchasesService.createSupplierPurchase(
    req.user.companyId,
    {
      ...req.body,
      supplierId: req.params.id,
    },
  );
  res.status(201).json({
    data: result,
  });
});

const getPaymentsHandler = asyncHandler(async (req, res) => {
  const payments = await purchasesService.getSupplierPayments(
    req.user.companyId,
    req.params.id,
  );
  res.json({
    data: payments,
  });
});

const createPaymentHandler = asyncHandler(async (req, res) => {
  const result = await purchasesService.recordSupplierPayment(
    req.user.companyId,
    {
      ...req.body,
      supplierId: req.params.id,
    },
  );
  res.status(201).json({
    data: result,
  });
});

const getBalanceHandler = asyncHandler(async (req, res) => {
  const balance = await purchasesService.getSupplierBalance(
    req.user.companyId,
    req.params.id,
  );
  res.json({
    data: balance,
  });
});

const getStatementHandler = asyncHandler(async (req, res) => {
  const statement = await purchasesService.getSupplierStatement(
    req.user.companyId,
    req.params.id,
  );
  res.json({
    data: statement,
  });
});

const getStatementPdfHandler = asyncHandler(async (req, res) => {
  await purchasesService.streamSupplierStatementPdf(
    res,
    req.user.companyId,
    req.params.id,
  );
});

// Routes
const router = express.Router();

router.use(authMiddleware);

router.get('/', list);
router.get('/:id', getByIdHandler);
router.post('/', createHandler);
router.put('/:id', updateHandler);
router.delete('/:id', deleteHandler);

// Accounts Payable / Purchases & Payments
router.get('/:id/purchases', getPurchasesHandler);
router.post('/:id/purchases', createPurchaseHandler);
router.get('/:id/payments', getPaymentsHandler);
router.post('/:id/payments', createPaymentHandler);
router.get('/:id/balance', getBalanceHandler);
router.get('/:id/statement', getStatementHandler);
router.get('/:id/statement/pdf', getStatementPdfHandler);

router.findById = findById;
router.createSupplier = createSupplier;
router.updateSupplier = updateSupplier;
router.deleteSupplier = deleteSupplier;
router.createSupplierPurchase = purchasesService.createSupplierPurchase;
router.recordSupplierPayment = purchasesService.recordSupplierPayment;
router.getSupplierPurchases = purchasesService.getSupplierPurchases;
router.getSupplierPayments = purchasesService.getSupplierPayments;
router.getSupplierBalance = purchasesService.getSupplierBalance;
router.getSupplierStatement = purchasesService.getSupplierStatement;
router.streamSupplierStatementPdf = purchasesService.streamSupplierStatementPdf;

module.exports = router;
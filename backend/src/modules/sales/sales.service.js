const { withTransaction } = require('../../config/db');
const salesRepo = require('./sales.repository');
const productsRepo = require('../products/products.repository');
const ApiError = require('../../utils/ApiError');

const VALID_PAYMENT_STATUSES = ['paid', 'unpaid'];

function validateSaleInput({
  items,
  discount,
  paymentStatus,
}) {
  if (!Array.isArray(items) || items.length === 0) {
    throw ApiError.badRequest(
      'A sale must contain at least one item',
      'EMPTY_CART',
    );
  }

  if (
    discount !== undefined &&
    (typeof discount !== 'number' ||
      !Number.isFinite(discount) ||
      discount < 0)
  ) {
    throw ApiError.badRequest(
      'Discount must be a non-negative number',
      'VALIDATION_ERROR',
    );
  }

  if (!VALID_PAYMENT_STATUSES.includes(paymentStatus)) {
    throw ApiError.badRequest(
      `paymentStatus must be one of: ${VALID_PAYMENT_STATUSES.join(', ')}`,
      'VALIDATION_ERROR',
    );
  }

  const productIds = new Set();

  for (const item of items) {
    if (!item || typeof item !== 'object') {
      throw ApiError.badRequest(
        'Each sale item must be an object',
        'VALIDATION_ERROR',
      );
    }

    if (
      typeof item.productId !== 'string' ||
      item.productId.trim().length === 0
    ) {
      throw ApiError.badRequest(
        'Each sale item requires a valid productId',
        'VALIDATION_ERROR',
      );
    }

    if (
      typeof item.quantity !== 'number' ||
      !Number.isInteger(item.quantity) ||
      item.quantity <= 0
    ) {
      throw ApiError.badRequest(
        'Item quantity must be a positive integer',
        'VALIDATION_ERROR',
      );
    }

    if (productIds.has(item.productId)) {
      throw ApiError.badRequest(
        `Product ${item.productId} appears more than once in the sale`,
        'DUPLICATE_PRODUCT',
      );
    }

    productIds.add(item.productId);
  }
}

async function list(companyId) {
  return salesRepo.findAll(companyId);
}

async function getOne(companyId, id) {
  const sale = await salesRepo.findById(companyId, id);

  if (!sale) {
    throw ApiError.notFound('Sale not found');
  }

  return sale;
}

async function createSale(
  companyId,
  {
    customerId,
    employeeId,
    items,
    discount = 0,
    paymentStatus = 'paid',
    clientTransactionId,
  },
) {
  validateSaleInput({
    items,
    discount,
    paymentStatus,
  });

  // Idempotency check: if clientTransactionId already exists for this company,
  // return the existing sale and invoice immediately to prevent double charges.
  if (clientTransactionId) {
    const existing = await salesRepo.findByClientTransactionId(companyId, clientTransactionId);
    if (existing) {
      return existing;
    }
  }

  return withTransaction(async (client) => {
    // Check again inside transaction to prevent race conditions
    if (clientTransactionId) {
      const existing = await salesRepo.findByClientTransactionId(companyId, clientTransactionId);
      if (existing) {
        return existing;
      }
    }

    if (customerId) {
      const custCheck = await client.query(
        'SELECT id FROM customers WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
        [companyId, customerId],
      );
      if (custCheck.rows.length === 0) {
        throw ApiError.badRequest('Customer not found for this company', 'VALIDATION_ERROR');
      }
    }

    if (employeeId) {
      const empCheck = await client.query(
        'SELECT id FROM employees WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
        [companyId, employeeId],
      );
      if (empCheck.rows.length === 0) {
        throw ApiError.badRequest('Employee not found for this company', 'VALIDATION_ERROR');
      }
    }

    const productIds = items.map((item) => item.productId);

    const products = await productsRepo.findManyForUpdate(
      client,
      companyId,
      productIds,
    );

    const productMap = new Map(
      products.map((product) => [product.id, product]),
    );

    for (const item of items) {
      const product = productMap.get(item.productId);

      if (!product) {
        throw ApiError.badRequest(
          `Product ${item.productId} not found`,
          'PRODUCT_NOT_FOUND',
        );
      }

      if (product.quantity < item.quantity) {
        throw ApiError.badRequest(
          `Insufficient stock for ${product.name}: requested ${item.quantity}, have ${product.quantity}`,
          'INSUFFICIENT_STOCK',
        );
      }
    }

    let subtotal = 0;

    for (const item of items) {
      const product = productMap.get(item.productId);
      subtotal += Number(product.selling_price) * item.quantity;
    }

    const total = subtotal - discount;

    if (total < 0) {
      throw ApiError.badRequest(
        'Discount cannot exceed subtotal',
        'INVALID_DISCOUNT',
      );
    }

    const sale = await salesRepo.insertSale(client, companyId, {
      customerId,
      employeeId,
      subtotal,
      discount,
      total,
      paymentStatus,
      clientTransactionId,
    });

    const savedItems = [];

    for (const item of items) {
      const product = productMap.get(item.productId);

      const saved = await salesRepo.insertSaleItem(
        client,
        sale.id,
        {
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: Number(product.selling_price),
          unitCost: Number(product.purchase_price),
        },
      );

      savedItems.push(saved);

      await productsRepo.decrementStock(
        client,
        companyId,
        item.productId,
        item.quantity,
      );
    }

    const invoiceNumber = await salesRepo.nextInvoiceNumber(
      client,
      companyId,
    );

    const invoice = await salesRepo.insertInvoice(
      client,
      companyId,
      sale.id,
      invoiceNumber,
      paymentStatus === 'unpaid' ? 'unpaid' : 'paid',
    );

    return {
      sale,
      items: savedItems,
      invoice,
    };
  });
}

module.exports = {
  list,
  getOne,
  createSale,
};
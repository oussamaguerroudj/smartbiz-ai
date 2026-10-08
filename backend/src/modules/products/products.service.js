const repo = require('./products.repository');
const ApiError = require('../../utils/ApiError');

function validateNonNegativeNumber(value, fieldName) {
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    value < 0
  ) {
    throw ApiError.badRequest(
      `${fieldName} must be a non-negative finite number`,
      'VALIDATION_ERROR',
    );
  }
}

function validateNonNegativeInteger(value, fieldName) {
  if (
    !Number.isInteger(value) ||
    value < 0
  ) {
    throw ApiError.badRequest(
      `${fieldName} must be a non-negative integer`,
      'VALIDATION_ERROR',
    );
  }
}

function validateProductData(data = {}, { partial = false } = {}) {
  const {
    name,
    purchasePrice,
    sellingPrice,
    quantity,
    minimumStock,
  } = data;

  if (!partial || name !== undefined) {
    if (
      typeof name !== 'string' ||
      name.trim().length < 2 ||
      name.trim().length > 255
    ) {
      throw ApiError.badRequest(
        'name must be between 2 and 255 characters',
        'VALIDATION_ERROR',
      );
    }
  }

  if (!partial || purchasePrice !== undefined) {
    validateNonNegativeNumber(
      purchasePrice,
      'purchasePrice',
    );
  }

  if (!partial || sellingPrice !== undefined) {
    validateNonNegativeNumber(
      sellingPrice,
      'sellingPrice',
    );
  }

  if (quantity !== undefined) {
    validateNonNegativeInteger(quantity, 'quantity');
  }

  if (minimumStock !== undefined) {
    validateNonNegativeInteger(
      minimumStock,
      'minimumStock',
    );
  }
}

async function list(companyId, filters) {
  return repo.findAll(companyId, filters);
}

async function getOne(companyId, id) {
  const product = await repo.findById(companyId, id);

  if (!product) {
    throw ApiError.notFound('Product not found');
  }

  return product;
}

/**
 * Deliberately does NOT throw notFound — a barcode scan that matches no
 * product is an expected outcome the client needs to branch on (e.g.
 * "add as new product"), not an error condition.
 */
async function getByBarcode(companyId, barcode) {
  return repo.findByBarcode(companyId, barcode);
}

async function createProduct(companyId, data = {}) {
  validateProductData(data);

  return repo.create(companyId, {
    ...data,
    name: data.name.trim(),
  });
}

async function updateProduct(companyId, id, data = {}) {
  validateProductData(data, { partial: true });

  const updated = await repo.update(companyId, id, {
    ...data,
    ...(typeof data.name === 'string'
      ? { name: data.name.trim() }
      : {}),
  });

  if (!updated) {
    throw ApiError.notFound('Product not found');
  }

  return updated;
}

async function deleteProduct(companyId, id) {
  const deleted = await repo.softDelete(companyId, id);

  if (!deleted) {
    throw ApiError.notFound('Product not found');
  }

  return { id };
}

module.exports = {
  list,
  getOne,
  getByBarcode,
  createProduct,
  updateProduct,
  deleteProduct,
};
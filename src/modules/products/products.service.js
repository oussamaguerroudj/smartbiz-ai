const repo = require('./products.repository');
const ApiError = require('../../utils/ApiError');

async function list(companyId, filters) {
  return repo.findAll(companyId, filters);
}

async function getOne(companyId, id) {
  const product = await repo.findById(companyId, id);
  if (!product) throw ApiError.notFound('Product not found');
  return product;
}

async function createProduct(companyId, data) {
  // Spec Ch. 10.2 field rules — hard requirements only; "selling price
  // below purchase" is a UI-level WARNING per spec, not a server block.
  if (data.purchasePrice < 0 || data.sellingPrice < 0) {
    throw ApiError.badRequest('Prices must be ≥ 0', 'VALIDATION_ERROR');
  }
  if (data.quantity !== undefined && data.quantity < 0) {
    throw ApiError.badRequest('Quantity must be ≥ 0', 'VALIDATION_ERROR');
  }
  return repo.create(companyId, data);
}

async function updateProduct(companyId, id, data) {
  const updated = await repo.update(companyId, id, data);
  if (!updated) throw ApiError.notFound('Product not found');
  return updated;
}

async function deleteProduct(companyId, id) {
  const deleted = await repo.softDelete(companyId, id);
  if (!deleted) throw ApiError.notFound('Product not found');
  return { id };
}

module.exports = { list, getOne, createProduct, updateProduct, deleteProduct };

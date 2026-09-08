const asyncHandler = require('../../utils/asyncHandler');
const service = require('./products.service');

const list = asyncHandler(async (req, res) => {
  const products = await service.list(req.user.companyId, { search: req.query.search });
  res.json({ data: products });
});

const getOne = asyncHandler(async (req, res) => {
  const product = await service.getOne(req.user.companyId, req.params.id);
  res.json({ data: product });
});

const getByBarcode = asyncHandler(async (req, res) => {
  const product = await service.getByBarcode(req.user.companyId, req.params.code);
  // No match is a normal, expected result of a scan — 200 with a null
  // payload, not a 404, so the client doesn't need to special-case an
  // error status just to mean "nothing found".
  res.json({ data: product || null });
});

const create = asyncHandler(async (req, res) => {
  const product = await service.createProduct(req.user.companyId, req.body);
  res.status(201).json({ data: product });
});

const update = asyncHandler(async (req, res) => {
  const product = await service.updateProduct(req.user.companyId, req.params.id, req.body);
  res.json({ data: product });
});

const remove = asyncHandler(async (req, res) => {
  const result = await service.deleteProduct(req.user.companyId, req.params.id);
  res.json({ data: result });
});

module.exports = { list, getOne, getByBarcode, create, update, remove };

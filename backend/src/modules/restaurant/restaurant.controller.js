const asyncHandler = require('../../utils/asyncHandler');
const service = require('./restaurant.service');

const getDashboard = asyncHandler(async (req, res) => {
  res.json({ data: await service.getDashboard(req.user.companyId) });
});

// Inventory
const createInventoryItem = asyncHandler(async (req, res) => {
  const item = await service.createInventoryItem(req.user.companyId, req.user.id, req.body);
  res.status(201).json({ data: item });
});

const listInventoryItems = asyncHandler(async (req, res) => {
  const items = await service.listInventoryItems(req.user.companyId, {
    search: req.query.search,
    lowStockOnly: req.query.lowStockOnly === 'true',
  });
  res.json({ data: items });
});

const getInventoryItem = asyncHandler(async (req, res) => {
  const item = await service.getInventoryItem(req.user.companyId, req.params.id);
  res.json({ data: item });
});

const updateInventoryItem = asyncHandler(async (req, res) => {
  const item = await service.updateInventoryItem(req.user.companyId, req.params.id, req.body);
  res.json({ data: item });
});

const archiveInventoryItem = asyncHandler(async (req, res) => {
  const item = await service.archiveInventoryItem(req.user.companyId, req.params.id);
  res.json({ data: item });
});

const adjustInventoryQuantity = asyncHandler(async (req, res) => {
  const item = await service.adjustInventoryQuantity(
    req.user.companyId,
    req.user.id,
    req.params.id,
    req.body,
  );
  res.json({ data: item });
});

// Tables
const createTable = asyncHandler(async (req, res) => {
  const table = await service.createTable(req.user.companyId, req.body);
  res.status(201).json({ data: table });
});

const listTables = asyncHandler(async (req, res) => {
  res.json({ data: await service.listTables(req.user.companyId) });
});

const updateTableStatus = asyncHandler(async (req, res) => {
  const updated = await service.updateTableStatus(req.user.companyId, req.params.id, req.body.status);
  res.json({ data: updated });
});

const updateTable = asyncHandler(async (req, res) => {
  const updated = await service.updateTable(req.user.companyId, req.params.id, req.body);
  res.json({ data: updated });
});

const deleteTable = asyncHandler(async (req, res) => {
  await service.deleteTable(req.user.companyId, req.params.id);
  res.json({ message: 'Table deleted successfully' });
});

// Menu
const createMenuItem = asyncHandler(async (req, res) => {
  const item = await service.createMenuItem(req.user.companyId, req.body);
  res.status(201).json({ data: item });
});

const listMenuItems = asyncHandler(async (req, res) => {
  res.json({ data: await service.listMenuItems(req.user.companyId) });
});

const setMenuItemAvailability = asyncHandler(async (req, res) => {
  const updated = await service.setMenuItemAvailability(req.user.companyId, req.params.id, req.body.isAvailable);
  res.json({ data: updated });
});

const setMenuItemImage = asyncHandler(async (req, res) => {
  const updated = await service.setMenuItemImage(req.user.companyId, req.params.id, req.body.imageUrl);
  res.json({ data: updated });
});

const getMenuItemIngredients = asyncHandler(async (req, res) => {
  const lines = await service.getMenuItemIngredients(req.user.companyId, req.params.id);
  res.json({ data: lines });
});

const setMenuItemIngredients = asyncHandler(async (req, res) => {
  const lines = await service.setMenuItemIngredients(req.user.companyId, req.params.id, req.body.lines);
  res.json({ data: lines });
});

const updateMenuItem = asyncHandler(async (req, res) => {
  const updated = await service.updateMenuItem(req.user.companyId, req.params.id, req.body);
  res.json({ data: updated });
});

const deleteMenuItem = asyncHandler(async (req, res) => {
  await service.deleteMenuItem(req.user.companyId, req.params.id);
  res.status(204).send();
});

// Orders
const createOrder = asyncHandler(async (req, res) => {
  const order = await service.createOrder(req.user.companyId, req.body);
  res.status(201).json({ data: order });
});

const getOrderDetail = asyncHandler(async (req, res) => {
  const order = await service.getOrderDetail(req.user.companyId, req.params.id);
  res.json({ data: order });
});

const getActiveOrders = asyncHandler(async (req, res) => {
  res.json({ data: await service.getActiveOrders(req.user.companyId) });
});

const listOrders = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const orders = await service.listOrders(req.user.companyId, from && to ? { from, to } : undefined);
  res.json({ data: orders });
});

const updateOrderStatus = asyncHandler(async (req, res) => {
  const updated = await service.updateOrderStatus(req.user.companyId, req.params.id, req.body.status);
  res.json({ data: updated });
});

const recordPayment = asyncHandler(async (req, res) => {
  const result = await service.recordPayment(req.user.companyId, req.params.id, req.body);
  res.status(201).json({ data: result });
});

const refundOrder = asyncHandler(async (req, res) => {
  const result = await service.refundOrder(req.user.companyId, req.params.id, req.body?.note);
  res.json({ data: result });
});

const getOrderInvoice = asyncHandler(async (req, res) => {
  const invoice = await service.getOrderInvoice(req.user.companyId, req.params.id);
  res.json({ data: invoice });
});

const getOrderInvoicePdf = asyncHandler(async (req, res) => {
  await service.streamOrderInvoicePdf(res, req.user.companyId, req.params.id);
});

// Reservations
const createReservation = asyncHandler(async (req, res) => {
  const reservation = await service.createReservation(req.user.companyId, req.body);
  res.status(201).json({ data: reservation });
});

const listReservations = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const reservations = await service.listReservations(req.user.companyId, from && to ? { from, to } : undefined);
  res.json({ data: reservations });
});

const updateReservationStatus = asyncHandler(async (req, res) => {
  const updated = await service.updateReservationStatus(req.user.companyId, req.params.id, req.body.status);
  res.json({ data: updated });
});

const updateReservation = asyncHandler(async (req, res) => {
  const updated = await service.updateReservation(req.user.companyId, req.params.id, req.body);
  res.json({ data: updated });
});

const deleteReservation = asyncHandler(async (req, res) => {
  await service.deleteReservation(req.user.companyId, req.params.id);
  res.json({ message: 'Reservation deleted successfully' });
});

module.exports = {
  getDashboard,
  createTable,
  listTables,
  updateTableStatus,
  updateTable,
  deleteTable,
  createMenuItem,
  listMenuItems,
  setMenuItemAvailability,
  setMenuItemImage,
  getMenuItemIngredients,
  setMenuItemIngredients,
  updateMenuItem,
  deleteMenuItem,
  createOrder,
  getOrderDetail,
  getActiveOrders,
  listOrders,
  updateOrderStatus,
  recordPayment,
  refundOrder,
  getOrderInvoice,
  getOrderInvoicePdf,
  createReservation,
  listReservations,
  updateReservationStatus,
  updateReservation,
  deleteReservation,
  createInventoryItem,
  listInventoryItems,
  getInventoryItem,
  updateInventoryItem,
  archiveInventoryItem,
  adjustInventoryQuantity,
};

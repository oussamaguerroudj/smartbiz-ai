const repo = require('./restaurant.repository');
const expensesRepo = require('../expenses/expenses.repository');
const employeesRepo = require('../employees/employees.repository');
const { query } = require('../../config/db');
const pdfService = require('../../utils/pdf.service');
const ApiError = require('../../utils/ApiError');

function toDateStr(d) {
  return d.toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------

async function createTable(companyId, data) {
  if (typeof data.name !== 'string' || data.name.trim().length === 0) {
    throw ApiError.badRequest('name is required', 'VALIDATION_ERROR');
  }
  return repo.createTable(companyId, { ...data, name: data.name.trim() });
}

async function listTables(companyId) {
  return repo.findAllTables(companyId);
}

const VALID_TABLE_STATUSES = ['available', 'occupied', 'reserved', 'cleaning'];

async function updateTableStatus(companyId, id, status) {
  if (!VALID_TABLE_STATUSES.includes(status)) {
    throw ApiError.badRequest(`status must be one of: ${VALID_TABLE_STATUSES.join(', ')}`, 'VALIDATION_ERROR');
  }
  const updated = await repo.updateTableStatus(companyId, id, status);
  if (!updated) {
    throw ApiError.notFound('Table not found');
  }
  return updated;
}

async function updateTable(companyId, id, data) {
  const existing = await repo.findTableById(companyId, id);
  if (!existing) {
    throw ApiError.notFound('Table not found');
  }
  return repo.updateTable(companyId, id, data);
}

async function deleteTable(companyId, id) {
  const existing = await repo.findTableById(companyId, id);
  if (!existing) {
    throw ApiError.notFound('Table not found');
  }
  return repo.deleteTable(companyId, id);
}

// ---------------------------------------------------------------------
// Menu
// ---------------------------------------------------------------------

async function createMenuItem(companyId, data) {
  if (typeof data.name !== 'string' || data.name.trim().length === 0) {
    throw ApiError.badRequest('name is required', 'VALIDATION_ERROR');
  }
  return repo.createMenuItem(companyId, { ...data, name: data.name.trim() });
}

async function listMenuItems(companyId) {
  return repo.findAllMenuItems(companyId);
}

async function setMenuItemAvailability(companyId, id, isAvailable) {
  const updated = await repo.updateMenuItemAvailability(companyId, id, isAvailable);
  if (!updated) {
    throw ApiError.notFound('Menu item not found');
  }
  return updated;
}

async function setMenuItemImage(companyId, id, imageUrl) {
  const updated = await repo.updateMenuItemImage(companyId, id, imageUrl);
  if (!updated) {
    throw ApiError.notFound('Menu item not found');
  }
  return updated;
}

async function updateMenuItem(companyId, id, data = {}) {
  if (data.name !== undefined && (typeof data.name !== 'string' || data.name.trim().length === 0)) {
    throw ApiError.badRequest('name must be a non-empty string', 'VALIDATION_ERROR');
  }
  if (data.price !== undefined && (typeof data.price !== 'number' || Number.isNaN(data.price) || data.price < 0)) {
    throw ApiError.badRequest('price cannot be negative', 'VALIDATION_ERROR');
  }
  const updated = await repo.updateMenuItem(companyId, id, {
    name: data.name !== undefined ? data.name.trim() : undefined,
    category: data.category !== undefined ? data.category.trim() : undefined,
    price: data.price !== undefined ? Number(data.price) : undefined,
    isAvailable: data.isAvailable !== undefined ? Boolean(data.isAvailable) : undefined,
    imageUrl: data.imageUrl !== undefined ? data.imageUrl : undefined,
  });
  if (!updated) {
    throw ApiError.notFound('Menu item not found');
  }
  return updated;
}

async function deleteMenuItem(companyId, id) {
  const deleted = await repo.softDeleteMenuItem(companyId, id);
  if (!deleted) {
    throw ApiError.notFound('Menu item not found');
  }
  return deleted;
}

// ---------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------

async function requireOrder(companyId, orderId) {
  const order = await repo.findOrderById(companyId, orderId);
  if (!order) {
    throw ApiError.notFound('Order not found');
  }
  return order;
}

/**
 * `items` may reference an existing menu item (`menuItemId`) to pull
 * its current name/price, or be a free-form line (name + unitPrice
 * given directly)  -  either way the order stores its own snapshot, per
 * Ch. 17's "Menu items" + line-item pattern.
 */
async function createOrder(companyId, data) {
  if (!Array.isArray(data.items) || data.items.length === 0) {
    throw ApiError.badRequest('items must be a non-empty array', 'VALIDATION_ERROR');
  }

  const resolvedItems = [];
  for (const raw of data.items) {
    if (raw.menuItemId) {
      const menuItem = await repo.findMenuItemById(companyId, raw.menuItemId);
      if (!menuItem) {
        throw ApiError.badRequest(`Menu item ${raw.menuItemId} not found`, 'VALIDATION_ERROR');
      }
      resolvedItems.push({
        menuItemId: menuItem.id,
        name: menuItem.name,
        unitPrice: Number(menuItem.price),
        quantity: Number(raw.quantity) || 1,
      });
    } else {
      if (typeof raw.name !== 'string' || raw.name.trim().length === 0) {
        throw ApiError.badRequest('each item needs a menuItemId or a name', 'VALIDATION_ERROR');
      }
      resolvedItems.push({
        menuItemId: null,
        name: raw.name.trim(),
        unitPrice: Number(raw.unitPrice) || 0,
        quantity: Number(raw.quantity) || 1,
      });
    }
  }

  if (data.tableId) {
    const table = await repo.findTableById(companyId, data.tableId);
    if (!table) {
      throw ApiError.badRequest('Table not found', 'VALIDATION_ERROR');
    }
  }

  return repo.createOrder(companyId, {
    tableId: data.tableId,
    items: resolvedItems,
    notes: data.notes,
    customerName: data.customerName,
    customerId: data.customerId,
    orderType: data.orderType,
    customerPhone: data.customerPhone,
    deliveryAddress: data.deliveryAddress,
  });
}

async function getOrderDetail(companyId, orderId) {
  const order = await requireOrder(companyId, orderId);
  const items = await repo.findOrderItems(companyId, orderId);
  return { ...order, items };
}

async function getActiveOrders(companyId) {
  return repo.getActiveOrders(companyId);
}

async function listOrders(companyId, range) {
  return repo.findOrders(companyId, range);
}

async function updateOrder(companyId, id, data) {
  await requireOrder(companyId, id);
  if (data.tableId) {
    const table = await repo.findTableById(companyId, data.tableId);
    if (!table) {
      throw ApiError.badRequest('Table not found', 'VALIDATION_ERROR');
    }
  }
  return repo.updateOrder(companyId, id, data);
}

async function updateOrderStatus(companyId, id, status) {
  if (!repo.VALID_ORDER_STATUSES.includes(status)) {
    throw ApiError.badRequest(`status must be one of: ${repo.VALID_ORDER_STATUSES.join(', ')}`, 'VALIDATION_ERROR');
  }
  const order = await requireOrder(companyId, id);

  if (status === 'completed') {
    // Preparation rule: preparation must be finished (ready or served)
    if (order.status !== 'ready' && order.status !== 'served') {
      throw ApiError.badRequest('Order is not ready yet', 'ORDER_NOT_READY');
    }
    // Critical payment rule: payment_status must be paid
    if (order.payment_status !== 'paid' || Number(order.amount_paid) < Number(order.total_amount)) {
      throw ApiError.badRequest('Order payment is required before completion', 'ORDER_PAYMENT_REQUIRED');
    }
  }

  const updated = await repo.updateOrderStatus(companyId, id, status);
  if (!updated) {
    throw ApiError.notFound('Order not found');
  }
  return updated;
}

// ---------------------------------------------------------------------
// Payments (Ch. 17  -  revenue = actual order payments, never a separate
// product-sale calculation)
// ---------------------------------------------------------------------

/**
 * Ch. 11 "Prevent duplicate payment"  -  amount validated here; the
 * actual "already fully paid?" guard lives inside repo.recordPayment's
 * own FOR UPDATE-locked transaction (see its comment for why it can't
 * live here as a separate pre-check).
 */
async function recordPayment(companyId, orderId, data) {
  await requireOrder(companyId, orderId);

  const amount = Number(data.amount);
  if (!amount || amount <= 0) {
    throw ApiError.badRequest('amount must be a positive number', 'VALIDATION_ERROR');
  }

  let result;
  try {
    result = await repo.recordPayment(companyId, orderId, {
      amount,
      method: data.method,
      note: data.note,
      paidAt: data.paidAt,
    });
  } catch (err) {
    if (err && err.code === 'ORDER_ALREADY_PAID') {
      throw ApiError.conflict('This order is already fully paid', 'ORDER_ALREADY_PAID');
    }
    throw err;
  }

  if (!result) {
    throw ApiError.notFound('Order not found');
  }

  return result;
}

async function refundOrder(companyId, orderId, note) {
  await requireOrder(companyId, orderId);
  const result = await repo.refundOrder(companyId, orderId, note);
  if (!result) {
    throw ApiError.badRequest('This order has no payment to refund', 'NOTHING_TO_REFUND');
  }
  return result;
}

// ---------------------------------------------------------------------
// Order invoice (Ch. 8/9-equivalent)  -  computed, read-only view, same
// choice already made for Clinic (see clinic.service.getVisitInvoice's
// doc comment): the generic `invoices` table is tightly bound 1:1 to
// `sales` (invoices.sale_id is NOT NULL UNIQUE REFERENCES sales(id)  - 
// migration 008), which restaurant_orders is not and was never meant
// to be, so reusing it here would mean an invasive schema change to a
// core, heavily-used table just to bolt restaurant orders onto it.
// Deriving the invoice live from restaurant_orders +
// restaurant_order_items instead means it is automatically "created"
// (available) the instant an order's payment_status changes, is
// naturally idempotent  -  nothing is stored, so "call it twice after
// paying twice by accident" cannot produce two invoice rows  -  and can
// never drift from the order it represents.
// ---------------------------------------------------------------------

async function getCompany(companyId) {
  const result = await query(`SELECT name, phone, address FROM companies WHERE id = $1`, [companyId]);
  return result.rows[0] || {};
}

async function getOrderInvoice(companyId, orderId) {
  const order = await requireOrder(companyId, orderId);
  const items = await repo.findOrderItems(companyId, orderId);

  return {
    invoiceNumber: `RS-${new Date(order.created_at).getFullYear()}-${order.order_number}`,
    date: order.created_at,
    tableName: order.table_id ? (await repo.findTableById(companyId, order.table_id))?.name : null,
    customerName: order.customer_name || null,
    customerPhone: order.customer_phone || null,
    deliveryAddress: order.delivery_address || null,
    orderType: order.order_type || 'dine_in',
    items: items.map((it) => ({
      itemName: it.item_name,
      quantity: it.quantity,
      unitPrice: Number(it.unit_price),
      subtotal: Number(it.subtotal),
    })),
    totalAmount: Number(order.total_amount),
    amountPaid: Number(order.amount_paid),
    remaining: Math.max(Number(order.total_amount) - Number(order.amount_paid), 0),
    paymentStatus: order.payment_status,
  };
}

async function streamOrderInvoicePdf(res, companyId, orderId) {
  const [company, invoice] = await Promise.all([getCompany(companyId), getOrderInvoice(companyId, orderId)]);
  pdfService.streamRestaurantInvoicePdf(res, { company, invoice });
}

// ---------------------------------------------------------------------
// Reservations
// ---------------------------------------------------------------------

async function createReservation(companyId, data) {
  const customerName = (data.customerName || data.name || '').trim();
  const reservedAt = data.reservedAt || data.reservationTime;
  const phone = data.phone || data.customerPhone || null;
  const partySize = data.partySize || data.guestCount || 1;
  const tableId = data.tableId || null;
  const notes = data.notes || null;

  if (!customerName) {
    throw ApiError.badRequest('customerName is required', 'VALIDATION_ERROR');
  }
  if (!reservedAt || Number.isNaN(new Date(reservedAt).getTime())) {
    throw ApiError.badRequest('reservedAt must be a valid date/time', 'VALIDATION_ERROR');
  }
  return repo.createReservation(companyId, { customerName, phone, partySize, tableId, reservedAt, notes });
}

async function listReservations(companyId, range) {
  const list = await repo.findReservations(companyId, range);
  return list.map((r) => ({
    ...r,
    customerName: r.customer_name,
    customerPhone: r.phone,
    guestCount: r.party_size,
    partySize: r.party_size,
    reservationTime: r.reserved_at,
    reservedAt: r.reserved_at,
    tableName: r.table_name,
  }));
}

const VALID_RESERVATION_STATUSES = ['pending', 'confirmed', 'seated', 'completed', 'cancelled', 'no_show'];

async function updateReservationStatus(companyId, id, status) {
  if (!VALID_RESERVATION_STATUSES.includes(status)) {
    throw ApiError.badRequest(`status must be one of: ${VALID_RESERVATION_STATUSES.join(', ')}`, 'VALIDATION_ERROR');
  }
  const dbStatus = status === 'completed' ? 'seated' : status;
  const updated = await repo.updateReservationStatus(companyId, id, dbStatus);
  if (!updated) {
    throw ApiError.notFound('Reservation not found');
  }
  return updated;
}

async function updateReservation(companyId, id, data) {
  const customerName = data.customerName || data.name;
  const reservedAt = data.reservedAt || data.reservationTime;
  const phone = data.phone !== undefined ? (data.phone || data.customerPhone) : undefined;
  const partySize = data.partySize || data.guestCount;
  const tableId = data.tableId;
  const notes = data.notes;
  let status = data.status;
  if (status === 'completed') status = 'seated';

  const updated = await repo.updateReservation(companyId, id, {
    customerName,
    reservedAt,
    phone,
    partySize,
    tableId,
    notes,
    status,
  });
  if (!updated) {
    throw ApiError.notFound('Reservation not found');
  }
  return updated;
}

async function deleteReservation(companyId, id) {
  const deleted = await repo.deleteReservation(companyId, id);
  if (!deleted) {
    throw ApiError.notFound('Reservation not found');
  }
  return deleted;
}

// ---------------------------------------------------------------------
// Dashboard (Ch. 17  -  revenue/profit computed the same way as Clinic:
// revenue from the payments ledger, expenses from the shared generic
// expenses module, profit = revenue - expenses)
// ---------------------------------------------------------------------

// ---------------------------------------------------------------------
// Inventory (Ch. 13/14)
// ---------------------------------------------------------------------

async function createInventoryItem(companyId, userId, data) {
  if (typeof data.name !== 'string' || !data.name.trim()) {
    throw ApiError.badRequest('name is required', 'VALIDATION_ERROR');
  }
  if (data.purchasePrice != null && Number(data.purchasePrice) < 0) {
    throw ApiError.badRequest('purchasePrice cannot be negative', 'VALIDATION_ERROR');
  }
  if (data.sellingPrice != null && Number(data.sellingPrice) < 0) {
    throw ApiError.badRequest('sellingPrice cannot be negative', 'VALIDATION_ERROR');
  }
  if (data.openingQuantity != null && Number(data.openingQuantity) < 0) {
    throw ApiError.badRequest('openingQuantity cannot be negative', 'VALIDATION_ERROR');
  }
  return repo.createInventoryItem(companyId, { ...data, name: data.name.trim() }, userId);
}

async function listInventoryItems(companyId, { search, lowStockOnly } = {}) {
  return repo.findInventoryItems(companyId, { search, lowStockOnly });
}

async function getInventoryItem(companyId, itemId) {
  const item = await repo.findInventoryItemById(companyId, itemId);
  if (!item) {
    throw ApiError.notFound('Inventory item not found');
  }
  const movements = await repo.findInventoryMovements(companyId, itemId);
  return { ...item, movements };
}

async function updateInventoryItem(companyId, itemId, data) {
  if (data.purchasePrice != null && Number(data.purchasePrice) < 0) {
    throw ApiError.badRequest('purchasePrice cannot be negative', 'VALIDATION_ERROR');
  }
  if (data.sellingPrice != null && Number(data.sellingPrice) < 0) {
    throw ApiError.badRequest('sellingPrice cannot be negative', 'VALIDATION_ERROR');
  }
  const updated = await repo.updateInventoryItem(companyId, itemId, data);
  if (!updated) {
    throw ApiError.notFound('Inventory item not found');
  }
  return updated;
}

async function archiveInventoryItem(companyId, itemId) {
  const archived = await repo.archiveInventoryItem(companyId, itemId);
  if (!archived) {
    throw ApiError.notFound('Inventory item not found');
  }
  return archived;
}

const VALID_MOVEMENT_TYPES = new Set(['purchase', 'consumption', 'adjustment']);

/**
 * Ch. 14's manual-adjustment entry point, and Ch. 15's landing spot
 * once the user has reviewed and confirmed AI-scanned purchase lines  - 
 * the mobile client calls this once per confirmed line (same "loop and
 * call the existing per-item endpoint" pattern the generic Stock
 * module's own AiReviewScreen._confirmAndAddToInventory already uses;
 * see that screen's doc comment). Nothing on this path ever accepts an
 * AI-proposed quantity/price directly  -  by the time this is called the
 * user has already reviewed and could have edited every field.
 */
async function adjustInventoryQuantity(companyId, userId, itemId, data) {
  if (!VALID_MOVEMENT_TYPES.has(data.movementType)) {
    throw ApiError.badRequest(
      `movementType must be one of: ${[...VALID_MOVEMENT_TYPES].join(', ')}`,
      'VALIDATION_ERROR',
    );
  }
  const quantityChange = Number(data.quantityChange);
  if (!quantityChange) {
    throw ApiError.badRequest('quantityChange must be a non-zero number', 'VALIDATION_ERROR');
  }
  if (data.movementType === 'purchase' && quantityChange < 0) {
    throw ApiError.badRequest('A purchase movement must increase stock', 'VALIDATION_ERROR');
  }
  if (data.movementType === 'consumption' && quantityChange > 0) {
    throw ApiError.badRequest('A consumption movement must decrease stock', 'VALIDATION_ERROR');
  }

  const updated = await repo.adjustInventoryQuantity(companyId, itemId, {
    movementType: data.movementType,
    quantityChange,
    reference: data.reference,
    note: data.note,
    userId,
  });
  if (!updated) {
    throw ApiError.notFound('Inventory item not found');
  }
  return updated;
}

async function getDashboard(companyId) {
  const now = new Date();
  const todayStr = toDateStr(now);
  const weekStart = toDateStr(new Date(now.getTime() - 6 * 86400000));
  const monthStart = toDateStr(new Date(now.getFullYear(), now.getMonth(), 1));

  const [
    stats,
    todayRevenue,
    weekRevenue,
    monthRevenue,
    todayExpenses,
    todaySalaryCost,
    todayCogs,
    outstanding,
    bestSellers,
  ] = await Promise.all([
    repo.dashboardStats(companyId),
    repo.revenueForRange(companyId, todayStr, todayStr),
    repo.revenueForRange(companyId, weekStart, todayStr),
    repo.revenueForRange(companyId, monthStart, todayStr),
    expensesRepo.totalForRange(companyId, todayStr, todayStr),
    employeesRepo.totalSalaryCostForRange(companyId, todayStr, todayStr),
    // Ch. 16  -  see repo.costOfGoodsSoldForRange's doc comment: valued
    // from auto-deducted recipe consumption only, at current
    // purchase price.
    repo.costOfGoodsSoldForRange(companyId, todayStr, todayStr),
    repo.outstandingTotal(companyId),
    repo.bestSellingDishes(companyId, weekStart, todayStr, 5),
  ]);

  // Ch. 16: Rigorous accounting:
  //   revenue           = total order income received
  //   cogs              = cost of ingredients consumed for completed dishes
  //   grossProfit       = revenue - cogs
  //   totalExpenses     = operating expenses + employee salaries
  //   todayProfit (net) = grossProfit - totalExpenses
  const totalTodayExpenses = todayExpenses + todaySalaryCost;
  const grossProfit = Math.max(todayRevenue - todayCogs, 0);
  const netProfit = grossProfit - totalTodayExpenses;

  return {
    ...stats,
    todayRevenue,
    weekRevenue,
    monthRevenue,
    todayExpenses: totalTodayExpenses,
    todayOperatingExpenses: todayExpenses,
    todaySalaryCost,
    todayCostOfGoodsSold: todayCogs,
    todayGrossProfit: grossProfit,
    todayProfit: netProfit,
    outstandingPayments: outstanding,
    bestSellingDishes: bestSellers,
  };
}

// ---------------------------------------------------------------------
// Menu item recipes / BOM (Ch. 16)
// ---------------------------------------------------------------------

async function getMenuItemIngredients(companyId, menuItemId) {
  return repo.findMenuItemIngredients(companyId, menuItemId);
}

async function setMenuItemIngredients(companyId, menuItemId, lines) {
  if (!Array.isArray(lines)) {
    throw ApiError.badRequest('lines must be an array', 'VALIDATION_ERROR');
  }
  for (const line of lines) {
    if (typeof line.inventoryItemId !== 'string' || !line.inventoryItemId) {
      throw ApiError.badRequest('Each line requires an inventoryItemId', 'VALIDATION_ERROR');
    }
    if (!Number(line.quantityRequired) || Number(line.quantityRequired) <= 0) {
      throw ApiError.badRequest('Each line requires a positive quantityRequired', 'VALIDATION_ERROR');
    }
  }
  return repo.setMenuItemIngredients(companyId, menuItemId, lines);
}

module.exports = {
  createTable,
  listTables,
  updateTableStatus,
  updateTable,
  deleteTable,
  createMenuItem,
  listMenuItems,
  setMenuItemAvailability,
  updateMenuItem,
  deleteMenuItem,
  createOrder,
  updateOrder,
  getOrderDetail,
  getActiveOrders,
  listOrders,
  updateOrderStatus,
  recordPayment,
  refundOrder,
  getOrderInvoice,
  streamOrderInvoicePdf,
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
  setMenuItemImage,
  getMenuItemIngredients,
  setMenuItemIngredients,
  getDashboard,
};

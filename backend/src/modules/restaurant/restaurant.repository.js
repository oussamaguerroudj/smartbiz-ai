const { query, withTransaction } = require('../../config/db');

// ---------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------

async function createTable(companyId, { name, seats }) {
  const result = await query(
    `INSERT INTO restaurant_tables (company_id, name, seats)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [companyId, name, seats || 2],
  );
  return result.rows[0];
}

async function findAllTables(companyId) {
  const result = await query(
    `SELECT * FROM restaurant_tables WHERE company_id = $1 AND deleted_at IS NULL ORDER BY name`,
    [companyId],
  );
  return result.rows;
}

async function findTableById(companyId, id) {
  const result = await query(
    `SELECT * FROM restaurant_tables WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function updateTableStatus(companyId, id, status) {
  const result = await query(
    `UPDATE restaurant_tables SET status = $3 WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL RETURNING *`,
    [companyId, id, status],
  );
  return result.rows[0] || null;
}

async function updateTable(companyId, id, { name, seats, status }) {
  const result = await query(
    `UPDATE restaurant_tables
     SET name = COALESCE($3, name),
         seats = COALESCE($4, seats),
         status = COALESCE($5, status)
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [companyId, id, name || null, seats ? Number(seats) : null, status || null],
  );
  return result.rows[0] || null;
}

async function deleteTable(companyId, id) {
  const result = await query(
    `UPDATE restaurant_tables
     SET deleted_at = NOW()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Menu items
// ---------------------------------------------------------------------

async function createMenuItem(companyId, { name, category, price, isAvailable, imageUrl }) {
  const result = await query(
    `INSERT INTO restaurant_menu_items (company_id, name, category, price, is_available, image_url)
     VALUES ($1, $2, $3, $4, COALESCE($5, true), $6)
     RETURNING *`,
    [companyId, name, category || null, price || 0, isAvailable, imageUrl || null],
  );
  return result.rows[0];
}

async function findAllMenuItems(companyId) {
  const result = await query(
    `SELECT * FROM restaurant_menu_items WHERE company_id = $1 AND deleted_at IS NULL ORDER BY category NULLS LAST, name`,
    [companyId],
  );
  return result.rows;
}

async function findMenuItemById(companyId, id) {
  const result = await query(
    `SELECT * FROM restaurant_menu_items WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function updateMenuItemAvailability(companyId, id, isAvailable) {
  const result = await query(
    `UPDATE restaurant_menu_items SET is_available = $3 WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL RETURNING *`,
    [companyId, id, isAvailable],
  );
  return result.rows[0] || null;
}

/** Ch. 17/18 — same narrow single-purpose setter style as
 * updateMenuItemAvailability just above, rather than a broader PATCH
 * this module never had. */
async function updateMenuItemImage(companyId, id, imageUrl) {
  const result = await query(
    `UPDATE restaurant_menu_items SET image_url = $3 WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL RETURNING *`,
    [companyId, id, imageUrl],
  );
  return result.rows[0] || null;
}

async function updateMenuItem(companyId, id, { name, category, price, isAvailable, imageUrl } = {}) {
  const result = await query(
    `UPDATE restaurant_menu_items
     SET name = COALESCE($3, name),
         category = COALESCE($4, category),
         price = COALESCE($5, price),
         is_available = COALESCE($6, is_available),
         image_url = CASE WHEN $7::text IS NOT NULL THEN (CASE WHEN $7::text = '' THEN NULL ELSE $7::text END) ELSE image_url END,
         updated_at = now()
     WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL
     RETURNING *`,
    [
      companyId,
      id,
      name !== undefined ? name : null,
      category !== undefined ? category : null,
      price !== undefined ? price : null,
      isAvailable !== undefined ? isAvailable : null,
      imageUrl !== undefined ? imageUrl : null,
    ],
  );
  return result.rows[0] || null;
}

async function softDeleteMenuItem(companyId, id) {
  const result = await query(
    `UPDATE restaurant_menu_items SET deleted_at = now() WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL RETURNING id`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------

/** Per-company-per-day order number ("#01, #02, ...") — same pattern
 * as clinic_queue's nextQueuePosition. */
async function nextOrderNumber(client, companyId) {
  const result = await client.query(
    `SELECT COALESCE(MAX(order_number), 0) + 1 AS next_number
     FROM restaurant_orders
     WHERE company_id = $1 AND created_at::date = CURRENT_DATE`,
    [companyId],
  );
  return result.rows[0].next_number;
}

/**
 * Creates an order with its line items in one transaction. `items` is
 * an array of `{ menuItemId?, name, unitPrice, quantity }` — name/price
 * are snapshotted onto restaurant_order_items so a later menu price
 * change never rewrites this order's total.
 */
async function createOrder(companyId, { tableId, items, notes, customerName, customerId, orderType, customerPhone, deliveryAddress }) {
  return withTransaction(async (client) => {
    const orderNumber = await nextOrderNumber(client, companyId);
    const totalAmount = items.reduce((sum, it) => sum + Number(it.unitPrice) * Number(it.quantity), 0);
    const resolvedOrderType = orderType || (tableId ? 'dine_in' : 'takeaway');

    const orderResult = await client.query(
      `INSERT INTO restaurant_orders (company_id, table_id, order_number, total_amount, notes, customer_name, customer_id, order_type, customer_phone, delivery_address)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        companyId,
        tableId || null,
        orderNumber,
        totalAmount,
        notes || null,
        customerName || null,
        customerId || null,
        resolvedOrderType,
        customerPhone || null,
        deliveryAddress || null,
      ],
    );
    const order = orderResult.rows[0];

    for (const it of items) {
      const subtotal = Number(it.unitPrice) * Number(it.quantity);
      await client.query(
        `INSERT INTO restaurant_order_items (company_id, order_id, menu_item_id, item_name, unit_price, quantity, subtotal)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [companyId, order.id, it.menuItemId || null, it.name, it.unitPrice, it.quantity, subtotal],
      );
    }

    if (tableId) {
      await client.query(
        `UPDATE restaurant_tables SET status = 'occupied' WHERE company_id = $1 AND id = $2`,
        [companyId, tableId],
      );
    }

    return order;
  });
}

async function findOrderItems(companyId, orderId) {
  const result = await query(
    `SELECT * FROM restaurant_order_items WHERE company_id = $1 AND order_id = $2 ORDER BY item_name`,
    [companyId, orderId],
  );
  return result.rows;
}

/** Today's active orders (kitchen/order board — Ch. 17.A), plus their table name. */
async function getActiveOrders(companyId) {
  const result = await query(
    `SELECT ro.*, rt.name AS table_name
     FROM restaurant_orders ro
     LEFT JOIN restaurant_tables rt ON rt.id = ro.table_id AND rt.company_id = ro.company_id
     WHERE ro.company_id = $1
       AND ro.created_at::date = CURRENT_DATE
       AND ro.status IN ('pending', 'preparing', 'ready', 'served')
     ORDER BY ro.order_number ASC`,
    [companyId],
  );
  return result.rows;
}

async function findOrders(companyId, { from, to } = {}) {
  if (from && to) {
    const result = await query(
      `SELECT ro.*, rt.name AS table_name
       FROM restaurant_orders ro
       LEFT JOIN restaurant_tables rt ON rt.id = ro.table_id AND rt.company_id = ro.company_id
       WHERE ro.company_id = $1 AND ro.created_at BETWEEN $2 AND $3
       ORDER BY ro.created_at DESC`,
      [companyId, from, to],
    );
    return result.rows;
  }
  const result = await query(
    `SELECT ro.*, rt.name AS table_name
     FROM restaurant_orders ro
     LEFT JOIN restaurant_tables rt ON rt.id = ro.table_id AND rt.company_id = ro.company_id
     WHERE ro.company_id = $1
     ORDER BY ro.created_at DESC
     LIMIT 100`,
    [companyId],
  );
  return result.rows;
}

async function findOrderById(companyId, id) {
  const result = await query(
    `SELECT ro.*, rt.name AS table_name
     FROM restaurant_orders ro
     LEFT JOIN restaurant_tables rt ON rt.id = ro.table_id AND rt.company_id = ro.company_id
     WHERE ro.company_id = $1 AND ro.id = $2`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

async function updateOrder(companyId, id, data) {
  const fields = [];
  const values = [companyId, id];
  let idx = 3;

  if (data.customerName !== undefined) {
    fields.push(`customer_name = $${idx++}`);
    values.push(data.customerName || null);
  }
  if (data.customerPhone !== undefined) {
    fields.push(`customer_phone = $${idx++}`);
    values.push(data.customerPhone || null);
  }
  if (data.deliveryAddress !== undefined) {
    fields.push(`delivery_address = $${idx++}`);
    values.push(data.deliveryAddress || null);
  }
  if (data.notes !== undefined) {
    fields.push(`notes = $${idx++}`);
    values.push(data.notes || null);
  }
  if (data.orderType !== undefined) {
    fields.push(`order_type = $${idx++}`);
    values.push(data.orderType);
  }
  if (data.tableId !== undefined) {
    if (data.tableId) {
      const tbl = await findTableById(companyId, data.tableId);
      if (!tbl) {
        const err = new Error('Table not found for this company');
        err.code = 'VALIDATION_ERROR';
        err.statusCode = 400;
        throw err;
      }
    }
    fields.push(`table_id = $${idx++}`);
    values.push(data.tableId || null);
  }

  if (fields.length === 0) {
    return findOrderById(companyId, id);
  }

  const result = await query(
    `UPDATE restaurant_orders
     SET ${fields.join(', ')}
     WHERE company_id = $1 AND id = $2
     RETURNING *`,
    values,
  );
  return result.rows[0] || null;
}

const VALID_ORDER_STATUSES = ['pending', 'preparing', 'ready', 'served', 'completed', 'cancelled'];

async function updateOrderStatus(companyId, id, status) {
  return withTransaction(async (client) => {
    // Lock row for update
    const existingRes = await client.query(
      `SELECT * FROM restaurant_orders WHERE company_id = $1 AND id = $2 FOR UPDATE`,
      [companyId, id],
    );
    const existing = existingRes.rows[0];
    if (!existing) return null;

    if (status === 'completed') {
      // 1. Preparation check: order must be ready or served
      if (existing.status !== 'ready' && existing.status !== 'served') {
        const err = new Error('Order is not ready yet');
        err.code = 'ORDER_NOT_READY';
        err.statusCode = 400;
        throw err;
      }
      // 2. Payment check: must be fully paid!
      const remaining = Number(existing.total_amount) - Number(existing.amount_paid);
      if (existing.payment_status !== 'paid' || remaining > 0) {
        const err = new Error('Order payment is required before completion');
        err.code = 'ORDER_PAYMENT_REQUIRED';
        err.statusCode = 400;
        throw err;
      }
    }

    const result = await client.query(
      `UPDATE restaurant_orders
       SET status = $3::restaurant_order_status_enum, completed_at = CASE WHEN $3::text = 'completed' THEN now() ELSE completed_at END
       WHERE company_id = $1 AND id = $2
       RETURNING *`,
      [companyId, id, status],
    );
    let order = result.rows[0];
    if (!order) return null;

    // Freeing the table happens the moment an order is completed or cancelled
    if ((status === 'completed' || status === 'cancelled') && order.table_id) {
      const stillActive = await client.query(
        `SELECT COUNT(*)::int AS count FROM restaurant_orders
         WHERE company_id = $1 AND table_id = $2 AND status IN ('pending', 'preparing', 'ready', 'served')`,
        [companyId, order.table_id],
      );
      if (stillActive.rows[0].count === 0) {
        await client.query(
          `UPDATE restaurant_tables SET status = 'available' WHERE company_id = $1 AND id = $2`,
          [companyId, order.table_id],
        );
      }
    }

    if (status === 'completed') {
      await deductIngredientsForOrder(client, companyId, order.id);
    }

    return order;
  });
}

async function deductIngredientsForOrder(client, companyId, orderId) {
  const reference = `order:${orderId}`;

  const already = await client.query(
    `SELECT 1 FROM restaurant_inventory_movements WHERE company_id = $1 AND reference = $2 LIMIT 1`,
    [companyId, reference],
  );
  if (already.rows.length > 0) return;

  const orderItems = await client.query(
    `SELECT menu_item_id, quantity FROM restaurant_order_items WHERE company_id = $1 AND order_id = $2 AND menu_item_id IS NOT NULL`,
    [companyId, orderId],
  );

  for (const orderItem of orderItems.rows) {
    const recipe = await client.query(
      `SELECT inventory_item_id, quantity_required
       FROM restaurant_menu_item_ingredients
       WHERE company_id = $1 AND menu_item_id = $2`,
      [companyId, orderItem.menu_item_id],
    );

    for (const line of recipe.rows) {
      const totalDeduction = Number(line.quantity_required) * Number(orderItem.quantity);

      const itemResult = await client.query(
        `SELECT * FROM restaurant_inventory_items WHERE company_id = $1 AND id = $2 AND archived_at IS NULL FOR UPDATE`,
        [companyId, line.inventory_item_id],
      );
      const inventoryItem = itemResult.rows[0];
      if (!inventoryItem) continue;

      const newQuantity = Number(inventoryItem.quantity) - totalDeduction;
      await client.query(
        `UPDATE restaurant_inventory_items SET quantity = $2, updated_at = now() WHERE id = $1 AND company_id = $3`,
        [inventoryItem.id, newQuantity, companyId],
      );
      await client.query(
        `INSERT INTO restaurant_inventory_movements
           (company_id, item_id, movement_type, quantity_change, reference, note)
         VALUES ($1, $2, 'consumption', $3, $4, 'Auto-deducted on order completion')`,
        [companyId, inventoryItem.id, -totalDeduction, reference],
      );
    }
  }
}

// ---------------------------------------------------------------------
// Menu item recipes / BOM (Ch. 16)
// ---------------------------------------------------------------------

async function findMenuItemIngredients(companyId, menuItemId) {
  const result = await query(
    `SELECT mi.id, mi.inventory_item_id, mi.quantity_required, ii.name AS inventory_item_name, ii.unit
     FROM restaurant_menu_item_ingredients mi
     JOIN restaurant_inventory_items ii ON ii.id = mi.inventory_item_id AND ii.company_id = mi.company_id
     WHERE mi.company_id = $1 AND mi.menu_item_id = $2`,
    [companyId, menuItemId],
  );
  return result.rows;
}

async function setMenuItemIngredients(companyId, menuItemId, lines) {
  return withTransaction(async (client) => {
    const menuCheck = await client.query(
      'SELECT id FROM restaurant_menu_items WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
      [companyId, menuItemId],
    );
    if (menuCheck.rows.length === 0) {
      const ApiError = require('../../utils/ApiError');
      throw ApiError.notFound('Menu item not found');
    }

    for (const line of lines) {
      const invCheck = await client.query(
        'SELECT id FROM restaurant_inventory_items WHERE company_id = $1 AND id = $2 AND archived_at IS NULL',
        [companyId, line.inventoryItemId],
      );
      if (invCheck.rows.length === 0) {
        const ApiError = require('../../utils/ApiError');
        throw ApiError.badRequest(
          'Inventory item not found for this company',
          'VALIDATION_ERROR',
        );
      }
    }

    await client.query(
      `DELETE FROM restaurant_menu_item_ingredients WHERE company_id = $1 AND menu_item_id = $2`,
      [companyId, menuItemId],
    );
    for (const line of lines) {
      await client.query(
        `INSERT INTO restaurant_menu_item_ingredients (company_id, menu_item_id, inventory_item_id, quantity_required)
         VALUES ($1, $2, $3, $4)`,
        [companyId, menuItemId, line.inventoryItemId, line.quantityRequired],
      );
    }
    return findMenuItemIngredientsInTransaction(client, companyId, menuItemId);
  });
}

async function findMenuItemIngredientsInTransaction(client, companyId, menuItemId) {
  const result = await client.query(
    `SELECT mi.id, mi.inventory_item_id, mi.quantity_required, ii.name AS inventory_item_name, ii.unit
     FROM restaurant_menu_item_ingredients mi
     JOIN restaurant_inventory_items ii ON ii.id = mi.inventory_item_id AND ii.company_id = mi.company_id
     WHERE mi.company_id = $1 AND mi.menu_item_id = $2`,
    [companyId, menuItemId],
  );
  return result.rows;
}

async function costOfGoodsSoldForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT COALESCE(SUM(-m.quantity_change * ii.purchase_price), 0) AS total
     FROM restaurant_inventory_movements m
     JOIN restaurant_inventory_items ii ON ii.id = m.item_id AND ii.company_id = m.company_id
     WHERE m.company_id = $1
       AND m.movement_type = 'consumption'
       AND m.reference LIKE 'order:%'
       AND m.created_at::date BETWEEN $2::date AND $3::date`,
    [companyId, rangeStart, rangeEnd],
  );
  return Number(result.rows[0].total);
}

function derivePaymentStatus(totalAmount, amountPaid) {
  const total = Number(totalAmount);
  const paid = Number(amountPaid);
  if (paid <= 0) return 'unpaid';
  if (paid < total) return 'partially_paid';
  return 'paid';
}

async function recordPayment(companyId, orderId, { amount, method, note, paidAt }) {
  return withTransaction(async (client) => {
    const orderResult = await client.query(
      `SELECT * FROM restaurant_orders WHERE company_id = $1 AND id = $2 FOR UPDATE`,
      [companyId, orderId],
    );
    const order = orderResult.rows[0];
    if (!order) return null;

    const remainingDue = Math.max(0, Number(order.total_amount) - Number(order.amount_paid));
    if (order.payment_status === 'paid' || remainingDue <= 0) {
      const err = new Error('This order is already fully paid');
      err.code = 'ORDER_ALREADY_PAID';
      throw err;
    }

    const payableAmount = Math.min(Number(amount), remainingDue);

    const payment = await client.query(
      `INSERT INTO restaurant_payments (company_id, order_id, amount, method, note, paid_at)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6, now()))
       RETURNING *`,
      [companyId, orderId, payableAmount, method || null, note || null, paidAt || null],
    );

    const newAmountPaid = Number(order.amount_paid) + payableAmount;
    const newStatus = derivePaymentStatus(order.total_amount, newAmountPaid);

    const updatedOrder = await client.query(
      `UPDATE restaurant_orders SET amount_paid = $3, payment_status = $4
       WHERE company_id = $1 AND id = $2
       RETURNING *`,
      [companyId, orderId, newAmountPaid, newStatus],
    );

    return { order: updatedOrder.rows[0], payment: payment.rows[0] };
  });
}

async function refundOrder(companyId, orderId, note) {
  return withTransaction(async (client) => {
    const orderResult = await client.query(
      `SELECT * FROM restaurant_orders WHERE company_id = $1 AND id = $2 FOR UPDATE`,
      [companyId, orderId],
    );
    const order = orderResult.rows[0];
    if (!order || Number(order.amount_paid) <= 0) return null;

    const refundAmount = -Number(order.amount_paid);

    const payment = await client.query(
      `INSERT INTO restaurant_payments (company_id, order_id, amount, method, note)
       VALUES ($1, $2, $3, 'refund', $4)
       RETURNING *`,
      [companyId, orderId, refundAmount, note || null],
    );

    const updatedOrder = await client.query(
      `UPDATE restaurant_orders SET amount_paid = 0, payment_status = 'refunded'
       WHERE company_id = $1 AND id = $2
       RETURNING *`,
      [companyId, orderId],
    );

    return { order: updatedOrder.rows[0], payment: payment.rows[0] };
  });
}

async function revenueForRange(companyId, rangeStart, rangeEnd) {
  const result = await query(
    `SELECT COALESCE(SUM(amount), 0) AS total FROM restaurant_payments
     WHERE company_id = $1 AND paid_at::date BETWEEN $2::date AND $3::date`,
    [companyId, rangeStart, rangeEnd],
  );
  return Number(result.rows[0].total);
}

async function outstandingTotal(companyId) {
  const result = await query(
    `SELECT COALESCE(SUM(total_amount - amount_paid), 0) AS total
     FROM restaurant_orders
     WHERE company_id = $1 AND payment_status IN ('unpaid', 'partially_paid')`,
    [companyId],
  );
  return Number(result.rows[0].total);
}

async function bestSellingDishes(companyId, rangeStart, rangeEnd, limit = 5) {
  const result = await query(
    `SELECT roi.item_name, SUM(roi.quantity)::int AS units_sold, SUM(roi.subtotal) AS revenue
     FROM restaurant_order_items roi
     JOIN restaurant_orders ro ON ro.id = roi.order_id AND ro.company_id = roi.company_id
     WHERE roi.company_id = $1
       AND ro.status != 'cancelled'
       AND ro.created_at::date BETWEEN $2::date AND $3::date
     GROUP BY roi.item_name
     ORDER BY units_sold DESC
     LIMIT $4`,
    [companyId, rangeStart, rangeEnd, limit],
  );
  return result.rows;
}

// ---------------------------------------------------------------------
// Reservations
// ---------------------------------------------------------------------

async function createReservation(companyId, data) {
  if (data.tableId) {
    const tbl = await findTableById(companyId, data.tableId);
    if (!tbl) {
      const ApiError = require('../../utils/ApiError');
      throw ApiError.badRequest('Table not found for this company', 'VALIDATION_ERROR');
    }
  }
  const result = await query(
    `INSERT INTO restaurant_reservations (company_id, customer_name, phone, party_size, table_id, reserved_at, notes)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      companyId,
      data.customerName,
      data.phone || null,
      data.partySize || 1,
      data.tableId || null,
      data.reservedAt,
      data.notes || null,
    ],
  );
  return result.rows[0];
}

async function findReservations(companyId, { from, to } = {}) {
  if (from && to) {
    const result = await query(
      `SELECT rr.*, rt.name AS table_name
       FROM restaurant_reservations rr
       LEFT JOIN restaurant_tables rt ON rt.id = rr.table_id AND rt.company_id = rr.company_id
       WHERE rr.company_id = $1 AND rr.reserved_at BETWEEN $2 AND $3
       ORDER BY rr.reserved_at`,
      [companyId, from, to],
    );
    return result.rows;
  }
  const result = await query(
    `SELECT rr.*, rt.name AS table_name
     FROM restaurant_reservations rr
     LEFT JOIN restaurant_tables rt ON rt.id = rr.table_id AND rt.company_id = rr.company_id
     WHERE rr.company_id = $1 AND rr.reserved_at >= CURRENT_DATE
     ORDER BY rr.reserved_at
     LIMIT 100`,
    [companyId],
  );
  return result.rows;
}

async function updateReservationStatus(companyId, id, status) {
  const result = await query(
    `UPDATE restaurant_reservations SET status = $3 WHERE company_id = $1 AND id = $2 RETURNING *`,
    [companyId, id, status],
  );
  return result.rows[0] || null;
}

async function updateReservation(companyId, id, data) {
  if (data.tableId) {
    const tbl = await findTableById(companyId, data.tableId);
    if (!tbl) {
      const ApiError = require('../../utils/ApiError');
      throw ApiError.badRequest('Table not found for this company', 'VALIDATION_ERROR');
    }
  }
  const fields = ['updated_at = NOW()'];
  const values = [companyId, id];
  let idx = 3;

  if (data.customerName !== undefined) {
    fields.push(`customer_name = $${idx++}`);
    values.push(data.customerName ? data.customerName.trim() : null);
  }
  if (data.phone !== undefined) {
    fields.push(`phone = $${idx++}`);
    values.push(data.phone ? data.phone.trim() : null);
  }
  if (data.partySize !== undefined) {
    fields.push(`party_size = $${idx++}`);
    values.push(data.partySize ? Number(data.partySize) : 1);
  }
  if (data.tableId !== undefined) {
    fields.push(`table_id = $${idx++}`);
    values.push(data.tableId || null);
  }
  if (data.reservedAt !== undefined) {
    fields.push(`reserved_at = $${idx++}`);
    values.push(data.reservedAt);
  }
  if (data.notes !== undefined) {
    fields.push(`notes = $${idx++}`);
    values.push(data.notes || null);
  }
  if (data.status !== undefined) {
    fields.push(`status = $${idx++}`);
    values.push(data.status);
  }

  const result = await query(
    `UPDATE restaurant_reservations
     SET ${fields.join(', ')}
     WHERE company_id = $1 AND id = $2
     RETURNING *`,
    values,
  );
  return result.rows[0] || null;
}

async function deleteReservation(companyId, id) {
  const result = await query(
    `DELETE FROM restaurant_reservations WHERE company_id = $1 AND id = $2 RETURNING *`,
    [companyId, id],
  );
  return result.rows[0] || null;
}

// ---------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------

async function dashboardStats(companyId) {
  const [
    ordersToday,
    activeOrders,
    pendingOrders,
    completedToday,
    cancelledToday,
    tablesTotal,
    tablesOccupied,
    reservationsToday,
  ] = await Promise.all([
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_orders
       WHERE company_id = $1 AND created_at::date = CURRENT_DATE`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_orders
       WHERE company_id = $1 AND created_at::date = CURRENT_DATE
         AND status IN ('pending', 'preparing', 'ready', 'served')`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_orders
       WHERE company_id = $1 AND created_at::date = CURRENT_DATE AND status = 'pending'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_orders
       WHERE company_id = $1 AND created_at::date = CURRENT_DATE AND status = 'completed'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_orders
       WHERE company_id = $1 AND created_at::date = CURRENT_DATE AND status = 'cancelled'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_tables WHERE company_id = $1 AND deleted_at IS NULL`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_tables
       WHERE company_id = $1 AND deleted_at IS NULL AND status = 'occupied'`,
      [companyId],
    ),
    query(
      `SELECT COUNT(*)::int AS count FROM restaurant_reservations
       WHERE company_id = $1 AND reserved_at::date = CURRENT_DATE AND status NOT IN ('cancelled', 'no_show')`,
      [companyId],
    ),
  ]);

  return {
    ordersToday: ordersToday.rows[0].count,
    activeOrders: activeOrders.rows[0].count,
    pendingOrders: pendingOrders.rows[0].count,
    completedToday: completedToday.rows[0].count,
    cancelledToday: cancelledToday.rows[0].count,
    tablesTotal: tablesTotal.rows[0].count,
    tablesOccupied: tablesOccupied.rows[0].count,
    tablesAvailable: Math.max(tablesTotal.rows[0].count - tablesOccupied.rows[0].count, 0),
    reservationsToday: reservationsToday.rows[0].count,
  };
}

// ---------------------------------------------------------------------
// Inventory (Ch. 13/14) — items + stock-movements ledger. See
// migration 023's header comment for the "quantity is a cache, the
// ledger is the source of truth" design and why it mirrors
// clinic_visits.amount_paid.
// ---------------------------------------------------------------------

async function createInventoryItem(companyId, data, userId) {
  return withTransaction(async (client) => {
    const itemResult = await client.query(
      `INSERT INTO restaurant_inventory_items (
         company_id, name, category, unit, minimum_stock, purchase_price,
         selling_price, supplier, expiration_date, image_url, notes
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        companyId,
        data.name,
        data.category || null,
        data.unit || 'unit',
        data.minimumStock || 0,
        data.purchasePrice || 0,
        data.sellingPrice ?? null,
        data.supplier || null,
        data.expirationDate || null,
        data.imageUrl || null,
        data.notes || null,
      ],
    );
    const item = itemResult.rows[0];

    const openingQty = Number(data.openingQuantity) || 0;
    if (openingQty !== 0) {
      await client.query(
        `UPDATE restaurant_inventory_items SET quantity = $2, updated_at = now() WHERE id = $1`,
        [item.id, openingQty],
      );
      await client.query(
        `INSERT INTO restaurant_inventory_movements
           (company_id, item_id, movement_type, quantity_change, reference, created_by)
         VALUES ($1, $2, 'initial', $3, 'Opening stock', $4)`,
        [companyId, item.id, openingQty, userId || null],
      );
      item.quantity = openingQty;
    }

    return item;
  });
}

async function findInventoryItems(companyId, { search, lowStockOnly } = {}) {
  const conditions = ['company_id = $1', 'archived_at IS NULL'];
  const params = [companyId];

  if (search) {
    params.push(`%${search}%`);
    conditions.push(`name ILIKE $${params.length}`);
  }
  if (lowStockOnly) {
    conditions.push('quantity <= minimum_stock');
  }

  const result = await query(
    `SELECT * FROM restaurant_inventory_items WHERE ${conditions.join(' AND ')} ORDER BY name ASC`,
    params,
  );
  return result.rows;
}

async function findInventoryItemById(companyId, itemId) {
  const result = await query(
    `SELECT * FROM restaurant_inventory_items WHERE company_id = $1 AND id = $2 AND archived_at IS NULL`,
    [companyId, itemId],
  );
  return result.rows[0] || null;
}

async function updateInventoryItem(companyId, itemId, data) {
  const result = await query(
    `UPDATE restaurant_inventory_items SET
       name = COALESCE($3, name),
       category = COALESCE($4, category),
       unit = COALESCE($5, unit),
       minimum_stock = COALESCE($6, minimum_stock),
       purchase_price = COALESCE($7, purchase_price),
       selling_price = COALESCE($8, selling_price),
       supplier = COALESCE($9, supplier),
       expiration_date = COALESCE($10, expiration_date),
       image_url = COALESCE($11, image_url),
       notes = COALESCE($12, notes),
       updated_at = now()
     WHERE company_id = $1 AND id = $2 AND archived_at IS NULL
     RETURNING *`,
    [
      companyId,
      itemId,
      data.name ?? null,
      data.category ?? null,
      data.unit ?? null,
      data.minimumStock ?? null,
      data.purchasePrice ?? null,
      data.sellingPrice ?? null,
      data.supplier ?? null,
      data.expirationDate ?? null,
      data.imageUrl ?? null,
      data.notes ?? null,
    ],
  );
  return result.rows[0] || null;
}

async function archiveInventoryItem(companyId, itemId) {
  const result = await query(
    `UPDATE restaurant_inventory_items SET archived_at = now(), updated_at = now()
     WHERE company_id = $1 AND id = $2 AND archived_at IS NULL
     RETURNING *`,
    [companyId, itemId],
  );
  return result.rows[0] || null;
}

/**
 * Ch. 14 — the ONLY way quantity ever changes after item creation. Locks
 * the item row (FOR UPDATE) so two concurrent adjustments (e.g. two AI
 * scan confirmations landing at once) can't both read the same starting
 * quantity and silently drop one of them — same concurrency pattern as
 * clinic_visits payments and restaurant_orders payments.
 */
async function adjustInventoryQuantity(companyId, itemId, { movementType, quantityChange, reference, note, userId }) {
  return withTransaction(async (client) => {
    const itemResult = await client.query(
      `SELECT * FROM restaurant_inventory_items
       WHERE company_id = $1 AND id = $2 AND archived_at IS NULL
       FOR UPDATE`,
      [companyId, itemId],
    );
    const item = itemResult.rows[0];
    if (!item) return null;

    const newQuantity = Number(item.quantity) + Number(quantityChange);

    const updated = await client.query(
      `UPDATE restaurant_inventory_items SET quantity = $2, updated_at = now()
       WHERE id = $1 AND company_id = $3
       RETURNING *`,
      [itemId, newQuantity, companyId],
    );

    await client.query(
      `INSERT INTO restaurant_inventory_movements
         (company_id, item_id, movement_type, quantity_change, reference, note, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [companyId, itemId, movementType, quantityChange, reference || null, note || null, userId || null],
    );

    return updated.rows[0];
  });
}

async function findInventoryMovements(companyId, itemId) {
  const result = await query(
    `SELECT * FROM restaurant_inventory_movements
     WHERE company_id = $1 AND item_id = $2
     ORDER BY created_at DESC`,
    [companyId, itemId],
  );
  return result.rows;
}

module.exports = {
  createTable,
  findAllTables,
  findTableById,
  updateTableStatus,
  updateTable,
  deleteTable,
  createMenuItem,
  findAllMenuItems,
  findMenuItemById,
  updateMenuItemAvailability,
  updateMenuItemImage,
  updateMenuItem,
  softDeleteMenuItem,
  createOrder,
  findOrderItems,
  getActiveOrders,
  findOrders,
  findOrderById,
  updateOrder,
  updateOrderStatus,
  recordPayment,
  refundOrder,
  revenueForRange,
  outstandingTotal,
  bestSellingDishes,
  createReservation,
  findReservations,
  updateReservationStatus,
  updateReservation,
  deleteReservation,
  dashboardStats,
  createInventoryItem,
  findInventoryItems,
  findInventoryItemById,
  updateInventoryItem,
  archiveInventoryItem,
  adjustInventoryQuantity,
  findInventoryMovements,
  findMenuItemIngredients,
  setMenuItemIngredients,
  costOfGoodsSoldForRange,
  VALID_ORDER_STATUSES,
};

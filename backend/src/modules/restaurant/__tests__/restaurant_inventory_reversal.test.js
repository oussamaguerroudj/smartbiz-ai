const { query } = require('../../../config/db');
const repo = require('../restaurant.repository');
const service = require('../restaurant.service');

describe('Restaurant Order Cancellation & Refund Inventory Safety Tests', () => {
  let companyAId;
  let companyBId;
  let inventoryItemAId;
  let inventoryItemBId;
  let menuItemAId;

  beforeAll(async () => {
    // 1. Create Company A (Restaurant)
    const compARes = await query(
      `INSERT INTO companies (name, business_type) VALUES ('Reversal Safety Resto A', 'restaurant') RETURNING id`,
    );
    companyAId = compARes.rows[0].id;

    // 2. Create Company B (Restaurant)
    const compBRes = await query(
      `INSERT INTO companies (name, business_type) VALUES ('Reversal Safety Resto B', 'restaurant') RETURNING id`,
    );
    companyBId = compBRes.rows[0].id;

    // 3. Create inventory items
    const invARes = await query(
      `INSERT INTO restaurant_inventory_items (company_id, name, unit, quantity, minimum_stock, purchase_price)
       VALUES ($1, 'Beef Patty', 'kg', 100.0, 10.0, 15.0) RETURNING id`,
      [companyAId],
    );
    inventoryItemAId = invARes.rows[0].id;

    const invBRes = await query(
      `INSERT INTO restaurant_inventory_items (company_id, name, unit, quantity, minimum_stock, purchase_price)
       VALUES ($1, 'Beef Patty B', 'kg', 50.0, 5.0, 15.0) RETURNING id`,
      [companyBId],
    );
    inventoryItemBId = invBRes.rows[0].id;

    // 4. Create menu item with ingredient recipe (2 units of Patty per Burger)
    const menuRes = await query(
      `INSERT INTO restaurant_menu_items (company_id, name, category, price, is_available)
       VALUES ($1, 'Classic Cheeseburger', 'Burgers', 500, true) RETURNING id`,
      [companyAId],
    );
    menuItemAId = menuRes.rows[0].id;

    await query(
      `INSERT INTO restaurant_menu_item_ingredients (company_id, menu_item_id, inventory_item_id, quantity_required)
       VALUES ($1, $2, $3, 2.0)`,
      [companyAId, menuItemAId, inventoryItemAId],
    );
  });

  afterAll(async () => {
    // Clean up test data safely
    await query(`DELETE FROM restaurant_inventory_movements WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM restaurant_menu_item_ingredients WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM restaurant_order_items WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM restaurant_payments WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM invoices WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM restaurant_orders WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM restaurant_menu_items WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM restaurant_inventory_items WHERE company_id IN ($1, $2)`, [companyAId, companyBId]);
    await query(`DELETE FROM companies WHERE id IN ($1, $2)`, [companyAId, companyBId]);
  });

  test('Rule A: Completed order cancellation must NOT automatically restore consumed ingredients', async () => {
    // 1. Create order for 3 burgers (requires 3 * 2 = 6 kg)
    const order = await repo.createOrder(companyAId, {
      items: [{ menuItemId: menuItemAId, name: 'Classic Cheeseburger', unitPrice: 500, quantity: 3 }],
      orderType: 'takeaway',
    });

    // Record payment and complete the order
    await repo.recordPayment(companyAId, order.id, { amount: 1500, method: 'cash' });
    await repo.updateOrderStatus(companyAId, order.id, 'ready');
    const completedOrder = await repo.updateOrderStatus(companyAId, order.id, 'completed');
    expect(completedOrder.status).toBe('completed');

    // Verify stock was deducted: 100 - 6 = 94
    const itemAfterCompletion = await repo.findInventoryItemById(companyAId, inventoryItemAId);
    expect(Number(itemAfterCompletion.quantity)).toBe(94);

    // Verify consumption movement exists
    const movementsAfterCompletion = await repo.findInventoryMovements(companyAId, inventoryItemAId);
    const deduction = movementsAfterCompletion.find((m) => m.reference === `order:${order.id}`);
    expect(deduction).toBeDefined();
    expect(deduction.movement_type).toBe('consumption');
    expect(Number(deduction.quantity_change)).toBe(-6);

    // 2. Now cancel the completed order
    const cancelledOrder = await repo.updateOrderStatus(companyAId, order.id, 'cancelled');
    expect(cancelledOrder.status).toBe('cancelled');

    // Rule A Requirement: Stock must REMAIN 94, NOT be restored to 100
    const itemAfterCancellation = await repo.findInventoryItemById(companyAId, inventoryItemAId);
    expect(Number(itemAfterCancellation.quantity)).toBe(94);

    // Rule A Requirement: Zero reversal movements created
    const movementsAfterCancellation = await repo.findInventoryMovements(companyAId, inventoryItemAId);
    const reversal = movementsAfterCancellation.find((m) => m.reference === `reversal:order:${order.id}`);
    expect(reversal).toBeUndefined();
  });

  test('Rule B: Refunding a customer must NOT automatically restore ingredients', async () => {
    // 1. Create order for 2 burgers (requires 2 * 2 = 4 kg)
    const order = await repo.createOrder(companyAId, {
      items: [{ menuItemId: menuItemAId, name: 'Classic Cheeseburger', unitPrice: 500, quantity: 2 }],
      orderType: 'takeaway',
    });

    await repo.recordPayment(companyAId, order.id, { amount: 1000, method: 'cash' });
    await repo.updateOrderStatus(companyAId, order.id, 'ready');
    await repo.updateOrderStatus(companyAId, order.id, 'completed');

    // Stock was 94, now 94 - 4 = 90
    const itemAfterCompletion = await repo.findInventoryItemById(companyAId, inventoryItemAId);
    expect(Number(itemAfterCompletion.quantity)).toBe(90);

    // 2. Issue financial refund via service
    const refundResult = await service.refundOrder(companyAId, order.id, 'Customer dissatisfied with taste');
    expect(refundResult.order.payment_status).toBe('refunded');
    expect(Number(refundResult.order.amount_paid)).toBe(0);
    expect(Number(refundResult.payment.amount)).toBe(-1000);
    expect(refundResult.payment.method).toBe('refund');

    // Rule B Requirement: Stock must REMAIN 90, NOT be restored to 94
    const itemAfterRefund = await repo.findInventoryItemById(companyAId, inventoryItemAId);
    expect(Number(itemAfterRefund.quantity)).toBe(90);

    // Rule B Requirement: No reversal movement created
    const movementsAfterRefund = await repo.findInventoryMovements(companyAId, inventoryItemAId);
    const reversal = movementsAfterRefund.find((m) => m.reference === `reversal:order:${order.id}`);
    expect(reversal).toBeUndefined();
  });

  test('Rule C: Canceling order before ingredient deduction creates zero stock movements', async () => {
    const stockBefore = Number((await repo.findInventoryItemById(companyAId, inventoryItemAId)).quantity);

    // Create order in pending
    const order = await repo.createOrder(companyAId, {
      items: [{ menuItemId: menuItemAId, name: 'Classic Cheeseburger', unitPrice: 500, quantity: 5 }],
      orderType: 'takeaway',
    });

    // Cancel order while still pending
    const cancelled = await repo.updateOrderStatus(companyAId, order.id, 'cancelled');
    expect(cancelled.status).toBe('cancelled');

    // Stock must remain unchanged
    const stockAfter = Number((await repo.findInventoryItemById(companyAId, inventoryItemAId)).quantity);
    expect(stockAfter).toBe(stockBefore);

    // No movements of any type for this order
    const movements = await repo.findInventoryMovements(companyAId, inventoryItemAId);
    const orderMovements = movements.filter((m) => m.reference === `order:${order.id}` || m.reference === `reversal:order:${order.id}`);
    expect(orderMovements.length).toBe(0);
  });

  test('Rule D: Genuine return of unused ingredients goes through explicit authorized manual adjustment', async () => {
    const stockBefore = Number((await repo.findInventoryItemById(companyAId, inventoryItemAId)).quantity);

    // Manager inspects unopened/uncooked patties returned to fridge and records explicit adjustment
    const adjustedItem = await repo.adjustInventoryQuantity(companyAId, inventoryItemAId, {
      movementType: 'adjustment',
      quantityChange: 4,
      note: 'Uncooked patties returned to fridge by kitchen manager',
    });

    expect(Number(adjustedItem.quantity)).toBe(stockBefore + 4);

    // Verify manual adjustment movement is logged properly
    const movements = await repo.findInventoryMovements(companyAId, inventoryItemAId);
    const manualAdjustment = movements.find(
      (m) => m.movement_type === 'adjustment' && m.note === 'Uncooked patties returned to fridge by kitchen manager',
    );
    expect(manualAdjustment).toBeDefined();
    expect(Number(manualAdjustment.quantity_change)).toBe(4);
  });

  test('Rule E: Repeated cancellation calls are idempotent and preserve historical records', async () => {
    // Create and complete order
    const order = await repo.createOrder(companyAId, {
      items: [{ menuItemId: menuItemAId, name: 'Classic Cheeseburger', unitPrice: 500, quantity: 1 }],
      orderType: 'takeaway',
    });
    await repo.recordPayment(companyAId, order.id, { amount: 500, method: 'cash' });
    await repo.updateOrderStatus(companyAId, order.id, 'ready');
    await repo.updateOrderStatus(companyAId, order.id, 'completed');

    const stockAfterCompleted = Number((await repo.findInventoryItemById(companyAId, inventoryItemAId)).quantity);

    // First cancel
    await repo.updateOrderStatus(companyAId, order.id, 'cancelled');
    expect(Number((await repo.findInventoryItemById(companyAId, inventoryItemAId)).quantity)).toBe(stockAfterCompleted);

    // Second cancel attempt
    await repo.updateOrderStatus(companyAId, order.id, 'cancelled');
    expect(Number((await repo.findInventoryItemById(companyAId, inventoryItemAId)).quantity)).toBe(stockAfterCompleted);

    // Historical consumption record remains intact
    const movements = await repo.findInventoryMovements(companyAId, inventoryItemAId);
    const consumption = movements.find((m) => m.reference === `order:${order.id}`);
    expect(consumption).toBeDefined();
    expect(Number(consumption.quantity_change)).toBe(-2);
  });

  test('Tenant isolation: Company B cannot access or affect Company A inventory or orders', async () => {
    // Create order in Company A
    const orderA = await repo.createOrder(companyAId, {
      items: [{ menuItemId: menuItemAId, name: 'Classic Cheeseburger', unitPrice: 500, quantity: 1 }],
      orderType: 'takeaway',
    });
    await repo.recordPayment(companyAId, orderA.id, { amount: 500, method: 'cash' });

    // Company B attempts to refund Company A's order
    await expect(service.refundOrder(companyBId, orderA.id, 'Cross-tenant breach')).rejects.toThrow();

    // Company B inventory remains completely unaffected
    const itemB = await repo.findInventoryItemById(companyBId, inventoryItemBId);
    expect(Number(itemB.quantity)).toBe(50);
  });
});

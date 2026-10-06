const { withTransaction, query } = require('../../config/db');
const repo = require('./credit.repository');
const productsRepo = require('../products/products.repository');
const ApiError = require('../../utils/ApiError');

function round2(n) {
  return Math.round(n * 100) / 100;
}

function validateItems(items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw ApiError.badRequest(
      'A credit sale must contain at least one item',
      'EMPTY_CART',
    );
  }

  const seen = new Set();

  for (const item of items) {
    if (!item || typeof item !== 'object') {
      throw ApiError.badRequest('Each item must be an object', 'VALIDATION_ERROR');
    }
    if (typeof item.productId !== 'string' || item.productId.trim().length === 0) {
      throw ApiError.badRequest('Each item requires a valid productId', 'VALIDATION_ERROR');
    }
    if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
      throw ApiError.badRequest('Item quantity must be a positive integer', 'VALIDATION_ERROR');
    }
    if (seen.has(item.productId)) {
      throw ApiError.badRequest(
        `Product ${item.productId} appears more than once`,
        'DUPLICATE_PRODUCT',
      );
    }
    seen.add(item.productId);
  }
}

/**
 * Creates one Credit Sale: validates stock, decrements inventory
 * (reusing the exact same products.repository functions the regular
 * Sales flow uses — Ch. 13/18: "حدّث المخزون حسب نظام Inventory
 * الموجود حاليًا"), records the purchase + line items, applies
 * "Amount to Pay Now" as an immediate payment, and updates the
 * customer's balance_due — all inside one transaction so a mid-way
 * failure leaves nothing partially applied.
 *
 * Ledger (Ch. 14 "يجب أن تظهر العملية كاملة في Transaction History"):
 * writes TWO customer_transactions rows when amountPaidNow > 0 — the
 * full purchase amount as new debt, then the payment reducing it —
 * rather than one opaque net figure, so both halves of the operation
 * are visible. The net change to balance_due is still exactly
 * (subtotal - amountPaidNow) either way — see Double Counting note
 * below.
 */
async function createCreditPurchase(
  companyId,
  userId,
  { customerId, items, amountPaidNow = 0, note },
) {
  validateItems(items);

  if (typeof customerId !== 'string' || customerId.trim().length === 0) {
    throw ApiError.badRequest('customerId is required', 'VALIDATION_ERROR');
  }

  if (
    typeof amountPaidNow !== 'number' ||
    !Number.isFinite(amountPaidNow) ||
    amountPaidNow < 0
  ) {
    throw ApiError.badRequest(
      'amountPaidNow must be a non-negative number',
      'VALIDATION_ERROR',
    );
  }

  return withTransaction(async (client) => {
    const customer = await repo.findCustomerForUpdate(client, companyId, customerId);
    if (!customer) {
      throw ApiError.notFound('Customer not found');
    }

    const productIds = items.map((i) => i.productId);
    const products = await productsRepo.findManyForUpdate(client, companyId, productIds);
    const productMap = new Map(products.map((p) => [p.id, p]));

    for (const item of items) {
      const product = productMap.get(item.productId);
      if (!product) {
        throw ApiError.badRequest(`Product ${item.productId} not found`, 'PRODUCT_NOT_FOUND');
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
    subtotal = round2(subtotal);

    // "لا تسمح بقيمة دفع أكبر من إجمالي العملية" — no explicit
    // overpayment support, so this is a hard validation error rather
    // than silently clamping the value.
    if (amountPaidNow > subtotal) {
      throw ApiError.badRequest(
        'amountPaidNow cannot exceed the total purchase amount',
        'INVALID_PAYMENT_AMOUNT',
      );
    }

    const remainingCredit = round2(subtotal - amountPaidNow);
    const status = remainingCredit === 0 ? 'paid' : amountPaidNow === 0 ? 'unpaid' : 'partial';

    const purchase = await repo.insertCreditPurchase(client, companyId, {
      customerId,
      subtotal,
      amountPaidNow,
      remainingCredit,
      status,
      createdBy: userId,
    });

    const savedItems = [];
    for (const item of items) {
      const product = productMap.get(item.productId);
      const unitPrice = Number(product.selling_price);
      const lineTotal = round2(unitPrice * item.quantity);

      savedItems.push(
        await repo.insertCreditPurchaseItem(client, purchase.id, {
          productId: item.productId,
          productName: product.name,
          quantity: item.quantity,
          unitPrice,
          lineTotal,
        }),
      );

      await productsRepo.decrementStock(client, companyId, item.productId, item.quantity);
    }

    // Ledger entry 1: the full purchase amount becomes debt.
    let runningBalance = await repo.adjustCustomerBalance(client, companyId, customerId, subtotal);
    await repo.insertCustomerTransaction(client, companyId, customerId, {
      type: 'credit_purchase',
      referenceId: purchase.id,
      amount: subtotal,
      balanceAfter: runningBalance,
      description: note || `Credit purchase (${items.length} item(s))`,
    });

    let payment = null;

    if (amountPaidNow > 0) {
      payment = await repo.insertCreditPayment(client, companyId, {
        customerId,
        creditPurchaseId: purchase.id,
        amount: amountPaidNow,
        note: 'Paid at time of purchase',
        createdBy: userId,
      });

      // Ledger entry 2: immediately reduces that same debt. Net effect
      // on balance_due across both entries = +remainingCredit, applied
      // exactly once — never double-counted.
      runningBalance = await repo.adjustCustomerBalance(
        client,
        companyId,
        customerId,
        -amountPaidNow,
      );
      await repo.insertCustomerTransaction(client, companyId, customerId, {
        type: 'payment',
        referenceId: payment.id,
        amount: -amountPaidNow,
        balanceAfter: runningBalance,
        description: 'Amount paid now',
      });
    }

    return {
      purchase: { ...purchase, remaining_credit: remainingCredit, status },
      items: savedItems,
      payment,
      customerBalance: runningBalance,
    };
  });
}

/**
 * Records a standalone payment against a customer's existing balance
 * (not tied to a specific purchase) — e.g. the customer comes back
 * later and pays some/all of what they owe.
 */
async function recordPayment(companyId, userId, { customerId, amount, note, clientId }) {
  if (typeof customerId !== 'string' || customerId.trim().length === 0) {
    throw ApiError.badRequest('customerId is required', 'VALIDATION_ERROR');
  }

  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    throw ApiError.badRequest('amount must be a positive number', 'VALIDATION_ERROR');
  }

  if (clientId) {
    const existingPayment = await repo.findPaymentByClientId(companyId, clientId);
    if (existingPayment) {
      const customer = await repo.findCustomerForUpdate(null, companyId, customerId).catch(() => null);
      return {
        payment: existingPayment,
        customerBalance: customer ? Number(customer.balance_due) : 0,
      };
    }
  }

  return withTransaction(async (client) => {
    if (clientId) {
      const existingPayment = await repo.findPaymentByClientId(companyId, clientId);
      if (existingPayment) {
        const customer = await repo.findCustomerForUpdate(client, companyId, customerId);
        return {
          payment: existingPayment,
          customerBalance: customer ? Number(customer.balance_due) : 0,
        };
      }
    }

    const customer = await repo.findCustomerForUpdate(client, companyId, customerId);
    if (!customer) {
      throw ApiError.notFound('Customer not found');
    }

    const currentBalance = Number(customer.balance_due);

    if (currentBalance <= 0) {
      throw ApiError.badRequest('This customer has no outstanding balance', 'NO_OUTSTANDING_BALANCE');
    }

    if (amount > currentBalance) {
      throw ApiError.badRequest(
        `Payment cannot exceed the outstanding balance (${currentBalance})`,
        'INVALID_PAYMENT_AMOUNT',
      );
    }

    const payment = await repo.insertCreditPayment(client, companyId, {
      customerId,
      creditPurchaseId: null,
      amount,
      note,
      createdBy: userId,
      clientId,
    });

    const runningBalance = await repo.adjustCustomerBalance(client, companyId, customerId, -amount);

    await repo.insertCustomerTransaction(client, companyId, customerId, {
      type: 'payment',
      referenceId: payment.id,
      amount: -amount,
      balanceAfter: runningBalance,
      description: note || 'Payment received',
    });

    return { payment, customerBalance: runningBalance };
  });
}

async function listCreditPurchases(companyId) {
  return repo.findAllCreditPurchases(companyId);
}

async function getCreditPurchase(companyId, id) {
  const purchase = await repo.findCreditPurchaseById(companyId, id);
  if (!purchase) {
    throw ApiError.notFound('Credit purchase not found');
  }
  return purchase;
}

async function getCustomerTransactions(companyId, customerId) {
  const customerResult = await query(
    `SELECT id FROM customers WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL`,
    [companyId, customerId],
  );
  if (!customerResult.rows[0]) {
    throw ApiError.notFound('Customer not found');
  }
  return repo.findCustomerTransactions(companyId, customerId);
}

async function getSummary(companyId) {
  return repo.summary(companyId);
}

module.exports = {
  createCreditPurchase,
  recordPayment,
  listCreditPurchases,
  getCreditPurchase,
  getCustomerTransactions,
  getSummary,
};

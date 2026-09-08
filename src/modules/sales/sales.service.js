const { withTransaction } = require('../../config/db');
const salesRepo = require('./sales.repository');
const productsRepo = require('../products/products.repository');
const ApiError = require('../../utils/ApiError');

async function list(companyId) {
  return salesRepo.findAll(companyId);
}

async function getOne(companyId, id) {
  const sale = await salesRepo.findById(companyId, id);
  if (!sale) throw ApiError.notFound('Sale not found');
  return sale;
}

/**
 * Implements Spec Ch. 11 EXACTLY:
 *   Create Sale → Validate user → Validate company → Validate products →
 *   Check stock → Create Sale → Create SaleItems → Update inventory →
 *   Calculate total → Calculate profit → Create invoice information →
 *   Commit transaction. On ANY failure: ROLLBACK.
 *
 * "Validate user" / "Validate company" already happened before this
 * function is even called — that's what authMiddleware does (a request
 * without a valid company-scoped JWT never reaches here). Everything
 * from "Validate products" onward happens inside a single DB
 * transaction using `SELECT ... FOR UPDATE` row locks, so two
 * concurrent sales for the same product can never both oversell stock
 * — the second one blocks until the first commits, then sees the
 * updated quantity and fails cleanly if it's no longer enough.
 */
async function createSale(companyId, { customerId, employeeId, items, discount = 0, paymentStatus = 'paid' }) {
  if (!items || items.length === 0) {
    throw ApiError.badRequest('A sale must contain at least one item', 'EMPTY_CART');
  }

  return withTransaction(async (client) => {
    const productIds = items.map((i) => i.productId);

    // Validate products (they exist, belong to this company) + lock rows
    const products = await productsRepo.findManyForUpdate(client, companyId, productIds);
    const productMap = new Map(products.map((p) => [p.id, p]));

    for (const item of items) {
      const product = productMap.get(item.productId);
      if (!product) {
        throw ApiError.badRequest(`Product ${item.productId} not found`, 'PRODUCT_NOT_FOUND');
      }
      // Check stock
      if (product.quantity < item.quantity) {
        throw ApiError.badRequest(
          `Insufficient stock for ${product.name}: requested ${item.quantity}, have ${product.quantity}`,
          'INSUFFICIENT_STOCK',
        );
      }
    }

    // Calculate total (server-side — never trust a client-sent total)
    let subtotal = 0;
    for (const item of items) {
      const product = productMap.get(item.productId);
      subtotal += Number(product.selling_price) * item.quantity;
    }
    const total = subtotal - discount;
    if (total < 0) {
      throw ApiError.badRequest('Discount cannot exceed subtotal', 'INVALID_DISCOUNT');
    }

    // Create Sale
    const sale = await salesRepo.insertSale(client, companyId, {
      customerId,
      employeeId,
      subtotal,
      discount,
      total,
      paymentStatus,
    });

    // Create SaleItems + Update inventory (profit is computed and
    // stored per line item here — see sales.repository.insertSaleItem —
    // so Dashboard/Reports never need to recompute it from scratch)
    const savedItems = [];
    for (const item of items) {
      const product = productMap.get(item.productId);
      const saved = await salesRepo.insertSaleItem(client, sale.id, {
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: Number(product.selling_price), // snapshot at time of sale
        unitCost: Number(product.purchase_price), // snapshot at time of sale
      });
      savedItems.push(saved);
      await productsRepo.decrementStock(client, companyId, item.productId, item.quantity);
    }

    // Create invoice
    const invoiceNumber = await salesRepo.nextInvoiceNumber(client, companyId);
    const invoice = await salesRepo.insertInvoice(
      client,
      companyId,
      sale.id,
      invoiceNumber,
      paymentStatus === 'unpaid' ? 'unpaid' : 'paid',
    );

    // withTransaction COMMITs automatically if we return normally, or
    // ROLLBACKs automatically if anything above threw.
    return { sale, items: savedItems, invoice };
  });
}

module.exports = { list, getOne, createSale };

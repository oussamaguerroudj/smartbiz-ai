const { withTransaction, query } = require('../../config/db');
const ApiError = require('../../utils/ApiError');
const repo = require('./supplier_purchases.repository');
const productsRepo = require('../products/products.repository');

function round2(num) {
  return Math.round((Number(num) + Number.EPSILON) * 100) / 100;
}

/**
 * Creates a supplier purchase invoice with line items atomically.
 */
async function createSupplierPurchase(companyId, data = {}) {
  const {
    supplierId,
    invoiceNumber,
    purchaseDate,
    items,
    amountPaid = 0,
    paymentMethod = 'cash',
    notes,
    clientTransactionId,
  } = data;

  if (!companyId) {
    throw ApiError.unauthorized('Company identification required');
  }

  if (!supplierId) {
    throw ApiError.badRequest('supplierId is required', 'VALIDATION_ERROR');
  }

  if (!Array.isArray(items) || items.length === 0) {
    throw ApiError.badRequest('At least one purchase item is required', 'VALIDATION_ERROR');
  }

  // Check idempotency before transaction
  if (clientTransactionId) {
    const existing = await repo.findPurchaseByClientTransactionId(null, companyId, clientTransactionId);
    if (existing) {
      const existingItems = await repo.findPurchaseItems(existing.id);
      return {
        purchase: {
          ...existing,
          items: existingItems,
        },
        idempotent: true,
      };
    }
  }

  // Validate items
  const validatedItems = [];
  let computedTotal = 0;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const productName = typeof item.productName === 'string' ? item.productName.trim() : (item.product_name || '').trim();
    if (!productName) {
      throw ApiError.badRequest(`Item #${i + 1} must have a valid product name`, 'VALIDATION_ERROR');
    }

    const quantity = Number(item.quantity);
    if (isNaN(quantity) || quantity <= 0) {
      throw ApiError.badRequest(`Item #${i + 1} quantity must be a positive number`, 'VALIDATION_ERROR');
    }

    const unitCost = Number(item.unitCost !== undefined ? item.unitCost : item.unit_cost);
    if (isNaN(unitCost) || unitCost < 0) {
      throw ApiError.badRequest(`Item #${i + 1} unit cost cannot be negative`, 'VALIDATION_ERROR');
    }

    const lineTotal = round2(quantity * unitCost);
    computedTotal = round2(computedTotal + lineTotal);

    validatedItems.push({
      productId: item.productId || item.product_id || null,
      productName,
      quantity,
      unitCost,
      lineTotal,
    });
  }

  const parsedAmountPaid = round2(Number(amountPaid) || 0);
  if (parsedAmountPaid < 0) {
    throw ApiError.badRequest('amountPaid cannot be negative', 'VALIDATION_ERROR');
  }
  if (parsedAmountPaid > computedTotal) {
    throw ApiError.badRequest(
      `Initial payment (${parsedAmountPaid}) cannot exceed purchase total (${computedTotal})`,
      'OVERPAYMENT_REJECTED',
    );
  }

  const outstandingBalance = round2(computedTotal - parsedAmountPaid);
  let paymentStatus = 'unpaid';
  if (outstandingBalance <= 0.005) {
    paymentStatus = 'paid';
  } else if (parsedAmountPaid > 0) {
    paymentStatus = 'partially_paid';
  }

  return withTransaction(async (client) => {
    // 1. Verify supplier belongs to company and is active
    const supRes = await client.query(
      'SELECT id, name FROM suppliers WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
      [companyId, supplierId],
    );
    if (!supRes.rows[0]) {
      throw ApiError.notFound('Supplier not found');
    }

    // 2. If clientTransactionId provided, double check in transaction
    if (clientTransactionId) {
      const existing = await repo.findPurchaseByClientTransactionId(client, companyId, clientTransactionId);
      if (existing) {
        const existingItems = await repo.findPurchaseItems(existing.id);
        return {
          purchase: {
            ...existing,
            items: existingItems,
          },
          idempotent: true,
        };
      }
    }

    // 3. Process catalog products stock increment
    const qtyByProductId = new Map();
    for (const item of validatedItems) {
      if (item.productId) {
        const qty = Math.round(Number(item.quantity));
        if (qty > 0) {
          qtyByProductId.set(item.productId, (qtyByProductId.get(item.productId) || 0) + qty);
        }
      }
    }

    if (qtyByProductId.size > 0) {
      const productIds = Array.from(qtyByProductId.keys()).sort();
      const products = await productsRepo.findManyForUpdate(client, companyId, productIds);
      const productMap = new Map(products.map((p) => [p.id, p]));

      for (const prodId of productIds) {
        if (!productMap.has(prodId)) {
          throw ApiError.badRequest(`Product ${prodId} not found for this company`, 'PRODUCT_NOT_FOUND');
        }
      }

      for (const [prodId, qty] of qtyByProductId.entries()) {
        await productsRepo.incrementStock(client, companyId, prodId, qty);
      }
    }

    // 4. Insert purchase
    const purchase = await repo.insertPurchase(client, companyId, {
      supplierId,
      invoiceNumber: invoiceNumber ? String(invoiceNumber).trim() : null,
      purchaseDate,
      totalAmount: computedTotal,
      amountPaid: parsedAmountPaid,
      outstandingBalance,
      paymentStatus,
      notes: notes ? String(notes).trim() : null,
      clientTransactionId: clientTransactionId ? String(clientTransactionId).trim() : null,
    });

    // 5. Insert items
    const insertedItems = [];
    for (const item of validatedItems) {
      const insertedItem = await repo.insertPurchaseItem(client, companyId, purchase.id, item);
      insertedItems.push(insertedItem);
    }

    // 5. If initial payment was made, record payment ledger entry
    let paymentRecord = null;
    if (parsedAmountPaid > 0) {
      paymentRecord = await repo.insertPayment(client, companyId, {
        supplierId,
        purchaseId: purchase.id,
        amount: parsedAmountPaid,
        paymentDate: purchaseDate || null,
        paymentMethod: paymentMethod || 'cash',
        reference: invoiceNumber ? `Initial payment - ${invoiceNumber}` : 'Initial purchase payment',
        notes: 'Recorded upon purchase creation',
        clientId: clientTransactionId ? `pay_${clientTransactionId}` : null,
      });
    }

    return {
      purchase: {
        ...purchase,
        items: insertedItems,
        initial_payment: paymentRecord,
      },
    };
  });
}

/**
 * Records a supplier payment against an invoice or overall supplier balance.
 */
async function recordSupplierPayment(companyId, data = {}) {
  const {
    supplierId,
    purchaseId,
    amount,
    paymentDate,
    paymentMethod = 'cash',
    reference,
    notes,
    clientId,
  } = data;

  if (!companyId) {
    throw ApiError.unauthorized('Company identification required');
  }

  if (!supplierId) {
    throw ApiError.badRequest('supplierId is required', 'VALIDATION_ERROR');
  }

  const parsedAmount = round2(Number(amount));
  if (isNaN(parsedAmount) || parsedAmount <= 0) {
    throw ApiError.badRequest('Payment amount must be greater than zero', 'VALIDATION_ERROR');
  }

  // Check idempotency before transaction
  if (clientId) {
    const existing = await repo.findPaymentByClientId(null, companyId, clientId);
    if (existing) {
      return {
        payment: existing,
        idempotent: true,
      };
    }
  }

  return withTransaction(async (client) => {
    // 1. Verify supplier belongs to company
    const supRes = await client.query(
      'SELECT id, name FROM suppliers WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
      [companyId, supplierId],
    );
    if (!supRes.rows[0]) {
      throw ApiError.notFound('Supplier not found');
    }

    // 2. Check idempotency inside transaction
    if (clientId) {
      const existing = await repo.findPaymentByClientId(client, companyId, clientId);
      if (existing) {
        return {
          payment: existing,
          idempotent: true,
        };
      }
    }

    // 3. Handle payment allocation
    if (purchaseId) {
      // Allocate strictly against the specified purchase
      const purchase = await repo.findPurchaseByIdForUpdate(client, companyId, purchaseId);
      if (!purchase) {
        throw ApiError.notFound('Purchase invoice not found');
      }
      if (purchase.supplier_id !== supplierId) {
        throw ApiError.badRequest('Invoice does not belong to this supplier', 'VALIDATION_ERROR');
      }

      const currentBalance = round2(Number(purchase.outstanding_balance));
      if (parsedAmount > currentBalance + 0.001) {
        throw ApiError.badRequest(
          `Payment amount (${parsedAmount}) exceeds invoice outstanding balance (${currentBalance})`,
          'OVERPAYMENT_REJECTED',
        );
      }

      const newAmountPaid = round2(Number(purchase.amount_paid) + parsedAmount);
      const newBalance = round2(Number(purchase.total_amount) - newAmountPaid);
      const updatedBalance = newBalance <= 0.005 ? 0 : newBalance;
      const newStatus = updatedBalance <= 0.005 ? 'paid' : 'partially_paid';

      await repo.updatePurchasePaymentStatus(
        client,
        companyId,
        purchase.id,
        newAmountPaid,
        updatedBalance,
        newStatus,
      );

      const payment = await repo.insertPayment(client, companyId, {
        supplierId,
        purchaseId,
        amount: parsedAmount,
        paymentDate,
        paymentMethod,
        reference,
        notes,
        clientId,
      });

      return {
        payment,
        purchase: {
          id: purchase.id,
          amount_paid: newAmountPaid,
          outstanding_balance: updatedBalance,
          payment_status: newStatus,
        },
      };
    } else {
      // General payment: verify total outstanding debt and allocate FIFO
      const unpaidPurchases = await repo.findUnpaidPurchasesForUpdate(client, companyId, supplierId);
      const totalOutstanding = round2(
        unpaidPurchases.reduce((acc, p) => acc + Number(p.outstanding_balance), 0),
      );

      if (unpaidPurchases.length === 0 || totalOutstanding <= 0.005) {
        throw ApiError.badRequest(
          'Supplier has no outstanding unpaid purchases',
          'NO_OUTSTANDING_DEBT',
        );
      }

      if (parsedAmount > totalOutstanding + 0.001) {
        throw ApiError.badRequest(
          `Payment amount (${parsedAmount}) exceeds total outstanding debt (${totalOutstanding})`,
          'OVERPAYMENT_REJECTED',
        );
      }

      let remaining = parsedAmount;
      const updatedPurchases = [];

      for (const p of unpaidPurchases) {
        if (remaining <= 0) break;
        const pBal = round2(Number(p.outstanding_balance));
        const alloc = Math.min(remaining, pBal);
        const newPaid = round2(Number(p.amount_paid) + alloc);
        const newBal = round2(Number(p.total_amount) - newPaid);
        const updatedBal = newBal <= 0.005 ? 0 : newBal;
        const newStatus = updatedBal <= 0.005 ? 'paid' : 'partially_paid';

        await repo.updatePurchasePaymentStatus(
          client,
          companyId,
          p.id,
          newPaid,
          updatedBal,
          newStatus,
        );

        updatedPurchases.push({
          id: p.id,
          allocated: alloc,
          outstanding_balance: updatedBal,
          payment_status: newStatus,
        });

        remaining = round2(remaining - alloc);
      }

      const payment = await repo.insertPayment(client, companyId, {
        supplierId,
        purchaseId: null,
        amount: parsedAmount,
        paymentDate,
        paymentMethod,
        reference,
        notes,
        clientId,
      });

      return {
        payment,
        allocated_purchases: updatedPurchases,
      };
    }
  });
}

async function getSupplierPurchases(companyId, supplierId) {
  if (!companyId || !supplierId) {
    throw ApiError.badRequest('companyId and supplierId are required');
  }
  return repo.findPurchasesBySupplier(companyId, supplierId);
}

async function getSupplierPayments(companyId, supplierId) {
  if (!companyId || !supplierId) {
    throw ApiError.badRequest('companyId and supplierId are required');
  }
  return repo.findPaymentsBySupplier(companyId, supplierId);
}

async function getSupplierBalance(companyId, supplierId) {
  if (!companyId || !supplierId) {
    throw ApiError.badRequest('companyId and supplierId are required');
  }
  return repo.getSupplierApBalance(companyId, supplierId);
}

async function getSupplierStatement(companyId, supplierId) {
  if (!companyId || !supplierId) {
    throw ApiError.badRequest('companyId and supplierId are required');
  }

  const supRes = await query(
    'SELECT * FROM suppliers WHERE company_id = $1 AND id = $2 AND deleted_at IS NULL',
    [companyId, supplierId],
  );
  const supplier = supRes.rows[0];
  if (!supplier) {
    throw ApiError.notFound('Supplier not found');
  }

  const [purchases, payments, balance] = await Promise.all([
    repo.findPurchasesBySupplier(companyId, supplierId),
    repo.findPaymentsBySupplier(companyId, supplierId),
    repo.getSupplierApBalance(companyId, supplierId),
  ]);

  const txs = [];
  for (const p of purchases) {
    txs.push({
      date: p.purchase_date || p.created_at,
      type: 'purchase',
      description: p.invoice_number ? `Facture Achat: ${p.invoice_number}` : 'Achat Fournisseur',
      reference: p.invoice_number || p.id,
      debit: Number(p.total_amount),
      credit: 0,
      timestamp: new Date(p.purchase_date || p.created_at).getTime(),
    });
  }
  for (const pay of payments) {
    txs.push({
      date: pay.payment_date || pay.created_at,
      type: 'payment',
      description: pay.reference || 'Règlement Fournisseur',
      reference: pay.reference || pay.id,
      debit: 0,
      credit: Number(pay.amount),
      timestamp: new Date(pay.payment_date || pay.created_at).getTime(),
    });
  }

  txs.sort((a, b) => a.timestamp - b.timestamp);

  let runningBal = 0;
  for (const t of txs) {
    runningBal = round2(runningBal + t.debit - t.credit);
    t.balanceAfter = runningBal;
  }

  const totalPurchases = purchases.reduce((sum, p) => sum + Number(p.total_amount), 0);
  const totalPaid = payments.reduce((sum, p) => sum + Number(p.amount), 0);

  return {
    supplier,
    statement: {
      totalPurchases: round2(totalPurchases),
      totalPaid: round2(totalPaid),
      balanceDue: round2(balance.total_outstanding_debt || (totalPurchases - totalPaid)),
      transactions: txs,
    },
  };
}

async function streamSupplierStatementPdf(res, companyId, supplierId) {
  const { supplier, statement } = await getSupplierStatement(companyId, supplierId);
  const compRes = await query('SELECT name, phone, address FROM companies WHERE id = $1', [companyId]);
  const company = compRes.rows[0] || {};
  const pdfService = require('../../utils/pdf.service');
  pdfService.streamSupplierStatementPdf(res, { company, supplier, statement });
}

async function getAllSupplierPurchases(companyId) {
  if (!companyId) {
    throw ApiError.badRequest('companyId is required');
  }
  return repo.findAllPurchases(companyId);
}

async function getAllSupplierPayments(companyId) {
  if (!companyId) {
    throw ApiError.badRequest('companyId is required');
  }
  return repo.findAllPayments(companyId);
}

module.exports = {
  createSupplierPurchase,
  recordSupplierPayment,
  getSupplierPurchases,
  getSupplierPayments,
  getSupplierBalance,
  getSupplierStatement,
  streamSupplierStatementPdf,
  getAllSupplierPurchases,
  getAllSupplierPayments,
};


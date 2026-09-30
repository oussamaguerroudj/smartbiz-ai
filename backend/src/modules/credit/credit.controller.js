const asyncHandler = require('../../utils/asyncHandler');
const service = require('./credit.service');

const createPurchase = asyncHandler(async (req, res) => {
  const result = await service.createCreditPurchase(
    req.user.companyId,
    req.user.id,
    {
      customerId: req.body.customerId,
      items: req.body.items,
      amountPaidNow: req.body.amountPaidNow ?? 0,
      note: req.body.note,
    },
  );
  res.status(201).json({ data: result });
});

const listPurchases = asyncHandler(async (req, res) => {
  res.json({ data: await service.listCreditPurchases(req.user.companyId) });
});

const getPurchase = asyncHandler(async (req, res) => {
  res.json({ data: await service.getCreditPurchase(req.user.companyId, req.params.id) });
});

const recordPayment = asyncHandler(async (req, res) => {
  const result = await service.recordPayment(req.user.companyId, req.user.id, {
    customerId: req.body.customerId,
    amount: req.body.amount,
    note: req.body.note,
  });
  res.status(201).json({ data: result });
});

const customerTransactions = asyncHandler(async (req, res) => {
  const transactions = await service.getCustomerTransactions(
    req.user.companyId,
    req.params.customerId,
  );
  res.json({ data: transactions });
});

const summary = asyncHandler(async (req, res) => {
  res.json({ data: await service.getSummary(req.user.companyId) });
});

module.exports = {
  createPurchase,
  listPurchases,
  getPurchase,
  recordPayment,
  customerTransactions,
  summary,
};

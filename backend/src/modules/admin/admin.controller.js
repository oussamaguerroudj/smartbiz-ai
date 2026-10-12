const asyncHandler = require('../../utils/asyncHandler');
const adminService = require('./admin.service');

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body || {};
  const result = await adminService.adminLogin({ email, password });
  return res.json({ data: result });
});

const getOverview = asyncHandler(async (req, res) => {
  const metrics = await adminService.getOverviewMetrics();
  return res.json({ data: metrics });
});

const listUsers = asyncHandler(async (req, res) => {
  const { page, limit, search, filter } = req.query || {};
  const result = await adminService.listUsers({ page, limit, search, filter });
  return res.json({ data: result });
});

const grantLifetime = asyncHandler(async (req, res) => {
  const { id } = req.params; // companyId
  const { reason } = req.body || {};
  const result = await adminService.grantLifetimeLicense({
    companyId: id,
    adminId: req.user.id,
    reason,
  });
  return res.json({ data: result });
});

const grantTemporary = asyncHandler(async (req, res) => {
  const { id } = req.params; // companyId
  const { durationPreset, customDays, reason } = req.body || {};
  const result = await adminService.grantTemporaryLicense({
    companyId: id,
    adminId: req.user.id,
    durationPreset,
    customDays,
    reason,
  });
  return res.json({ data: result });
});

const extendLicense = asyncHandler(async (req, res) => {
  const { id } = req.params; // companyId
  const { daysToAdd, reason } = req.body || {};
  const result = await adminService.extendTemporaryLicense({
    companyId: id,
    adminId: req.user.id,
    daysToAdd,
    reason,
  });
  return res.json({ data: result });
});

const setSuspension = asyncHandler(async (req, res) => {
  const { id } = req.params; // companyId
  const { isSuspended, reason } = req.body || {};
  const result = await adminService.setAccountSuspension({
    companyId: id,
    adminId: req.user.id,
    isSuspended,
    reason,
  });
  return res.json({ data: result });
});

const reviewApproval = asyncHandler(async (req, res) => {
  const { id } = req.params; // companyId
  const { status, notes } = req.body || {};
  const result = await adminService.reviewAccountApproval({
    companyId: id,
    adminId: req.user.id,
    status,
    notes,
  });
  return res.json({ data: result });
});

const listManualPayments = asyncHandler(async (req, res) => {
  const list = await adminService.listManualPayments();
  return res.json({ data: list });
});

const decideManualPayment = asyncHandler(async (req, res) => {
  const { id } = req.params; // requestId
  const { decision, rejectionReason, adminNotes } = req.body || {};
  const result = await adminService.decideManualPayment({
    requestId: id,
    adminId: req.user.id,
    decision,
    rejectionReason,
    adminNotes,
  });
  return res.json({ data: result });
});

const listSupport = asyncHandler(async (req, res) => {
  const { status } = req.query || {};
  const messages = await adminService.listSupportMessages({ status });
  return res.json({ data: messages });
});

const updateSupport = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { status, adminNotes } = req.body || {};
  const result = await adminService.updateSupportStatus({
    messageId: id,
    adminId: req.user.id,
    status,
    adminNotes,
  });
  return res.json({ data: result });
});

const listFeedback = asyncHandler(async (req, res) => {
  const { status } = req.query || {};
  const feedback = await adminService.listFeedback({ status });
  return res.json({ data: feedback });
});

const updateFeedback = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { status, adminNotes } = req.body || {};
  const result = await adminService.updateFeedbackStatus({
    feedbackId: id,
    status,
    adminNotes,
  });
  return res.json({ data: result });
});

const listAuditLogs = asyncHandler(async (req, res) => {
  const { limit, offset } = req.query || {};
  const logs = await adminService.getAuditLogs({ limit, offset });
  return res.json({ data: logs });
});

module.exports = {
  login,
  getOverview,
  listUsers,
  grantLifetime,
  grantTemporary,
  extendLicense,
  setSuspension,
  reviewApproval,
  listManualPayments,
  decideManualPayment,
  listSupport,
  updateSupport,
  listFeedback,
  updateFeedback,
  listAuditLogs,
};

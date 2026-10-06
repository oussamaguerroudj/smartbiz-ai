const asyncHandler = require('../../utils/asyncHandler');
const service = require('./ai.service');

const scanInvoice = asyncHandler(async (req, res) => {
  const result = await service.scanInvoice({
    companyId: req.user.companyId,
    userId: req.user.id,
    imageBase64: req.body.imageBase64,
    mimeType: req.body.mimeType,
    scanId: req.body.scanId,
  });

  res.json({ data: result });
});

const extractOcr = asyncHandler(async (req, res) => {
  const result = await service.extractOcr({
    companyId: req.user.companyId,
    userId: req.user.id,
    imageBase64: req.body.imageBase64,
    mimeType: req.body.mimeType,
  });

  res.json({ data: result });
});

const confirmScan = asyncHandler(async (req, res) => {
  await service.confirmAiLog(req.user.companyId, req.params.id);
  res.json({ data: { confirmed: true } });
});

const chat = asyncHandler(async (req, res) => {
  const result = await service.chat({
    companyId: req.user.companyId,
    userId: req.user.id,
    message: req.body.message,
    history: req.body.history,
  });

  res.json({ data: result });
});

const insights = asyncHandler(async (req, res) => {
  const result = await service.insights({
    companyId: req.user.companyId,
    userId: req.user.id,
  });

  res.json({ data: result });
});

const submitFeedback = asyncHandler(async (req, res) => {
  await service.submitFeedback(req.user.companyId, req.params.id, {
    feedback: req.body.feedback,
    correctedAnswer: req.body.correctedAnswer,
  });
  res.json({ data: { received: true } });
});

const health = asyncHandler(async (req, res) => {
  const result = await service.checkHealth();
  res.json({ data: result });
});

const getConfig = asyncHandler(async (req, res) => {
  const result = await service.getAiConfig();
  res.json({ data: result });
});

const updateConfig = asyncHandler(async (req, res) => {
  const result = await service.updateRuntimeAiConfig(req.body);
  res.json({ data: result });
});

module.exports = {
  scanInvoice,
  extractOcr,
  confirmScan,
  chat,
  insights,
  submitFeedback,
  health,
  getConfig,
  updateConfig,
};


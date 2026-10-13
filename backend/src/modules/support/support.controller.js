const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const asyncHandler = require('../../utils/asyncHandler');
const supportService = require('./support.service');

function extractOptionalUser(req) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length);
  try {
    const payload = jwt.verify(token, env.jwt.accessSecret, {
      algorithms: ['HS256'],
    });
    return {
      id: payload.sub,
      companyId: payload.companyId,
      role: payload.role,
    };
  } catch (_) {
    return null;
  }
}

const contact = asyncHandler(async (req, res) => {
  const user = extractOptionalUser(req);
  const { name, email, phone, category, subject, message } = req.body || {};

  const result = await supportService.submitContactMessage({
    name,
    email,
    phone,
    category,
    subject,
    message,
    userId: user?.id || null,
    companyId: user?.companyId || null,
  });

  return res.json({ data: result });
});

const feedback = asyncHandler(async (req, res) => {
  const user = extractOptionalUser(req);
  const { category, message, rating } = req.body || {};

  const result = await supportService.submitFeedback({
    category,
    message,
    rating,
    userId: user?.id || null,
    companyId: user?.companyId || null,
  });

  return res.json({ data: result });
});

const submitAppeal = asyncHandler(async (req, res) => {
  const { message, subject, contactPhone } = req.body || {};
  const result = await supportService.submitSuspensionAppeal({
    appealContext: req.appealContext,
    message,
    subject,
    contactPhone,
  });
  return res.status(201).json({ data: result });
});

const appealStatus = asyncHandler(async (req, res) => {
  const result = await supportService.getAppealStatus({
    appealContext: req.appealContext,
  });
  return res.json({ data: result });
});

module.exports = {
  contact,
  feedback,
  submitAppeal,
  appealStatus,
};


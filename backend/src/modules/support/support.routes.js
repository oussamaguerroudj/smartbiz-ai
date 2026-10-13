const express = require('express');
const { createRateLimiter } = require('../../middlewares/rateLimit.middleware');
const { appealAuthMiddleware } = require('../../middlewares/auth.middleware');
const supportController = require('./support.controller');

const router = express.Router();

const supportLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 20,
  keyPrefix: 'support-submit',
  message: 'Too many messages submitted. Please wait a few minutes.',
});

const appealLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10,
  keyPrefix: 'support-appeal',
  message: 'Too many appeal requests submitted. Please wait a few minutes.',
});

router.post('/contact', supportLimiter, supportController.contact);
router.post('/feedback', supportLimiter, supportController.feedback);
router.post('/appeal', appealLimiter, appealAuthMiddleware, supportController.submitAppeal);
router.get('/appeal/status', appealLimiter, appealAuthMiddleware, supportController.appealStatus);

module.exports = router;


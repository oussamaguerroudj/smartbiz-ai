const express = require('express');
const { createRateLimiter } = require('../../middlewares/rateLimit.middleware');
const supportController = require('./support.controller');

const router = express.Router();

const supportLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 20,
  keyPrefix: 'support-submit',
  message: 'Too many messages submitted. Please wait a few minutes.',
});

router.post('/contact', supportLimiter, supportController.contact);
router.post('/feedback', supportLimiter, supportController.feedback);

module.exports = router;

const express = require('express');
const controller = require('./auth.controller');
const {
  validateRegister,
  validateLogin,
  validateRefresh,
  validateVerifyEmail,
  validateResendVerification,
  validateForgotPassword,
  validateResetPassword,
} = require('./auth.validators');

const { authMiddleware } = require('../../middlewares/auth.middleware');
const {
  authAccountLimiter,
  loginIpLimiter,
  otpVerifyLimiter,
} = require('../../middlewares/rateLimit.middleware');

const router = express.Router();

// Public auth endpoints (protected by per-account/IP rate limiters)
router.post('/register', authAccountLimiter, validateRegister, controller.register);
router.post('/login', loginIpLimiter, authAccountLimiter, validateLogin, controller.login);
router.post('/refresh', validateRefresh, controller.refresh);
router.post('/verify-email', otpVerifyLimiter, validateVerifyEmail, controller.verifyEmail);
router.post('/resend-verification', otpVerifyLimiter, validateResendVerification, controller.resendVerification);
router.post('/forgot-password', otpVerifyLimiter, validateForgotPassword, controller.requestPasswordReset);
router.post('/reset-password', otpVerifyLimiter, validateResetPassword, controller.resetPassword);

// Authenticated profile & account endpoints
router.get('/profile', authMiddleware, controller.getProfile);
router.get('/me', authMiddleware, controller.getProfile);
router.put('/profile', authMiddleware, controller.updateProfile);
router.put('/change-password', authMiddleware, controller.changePassword);
router.delete('/account', authMiddleware, controller.deleteAccount);

module.exports = router;

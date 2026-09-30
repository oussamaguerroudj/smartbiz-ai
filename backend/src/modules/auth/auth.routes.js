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

const router = express.Router();

// Public auth endpoints
router.post('/register', validateRegister, controller.register);
router.post('/login', validateLogin, controller.login);
router.post('/refresh', validateRefresh, controller.refresh);
router.post('/verify-email', validateVerifyEmail, controller.verifyEmail);
router.post('/resend-verification', validateResendVerification, controller.resendVerification);
router.post('/forgot-password', validateForgotPassword, controller.requestPasswordReset);
router.post('/reset-password', validateResetPassword, controller.resetPassword);

// Authenticated profile & account endpoints
router.get('/profile', authMiddleware, controller.getProfile);
router.get('/me', authMiddleware, controller.getProfile);
router.put('/profile', authMiddleware, controller.updateProfile);
router.put('/change-password', authMiddleware, controller.changePassword);
router.delete('/account', authMiddleware, controller.deleteAccount);

module.exports = router;

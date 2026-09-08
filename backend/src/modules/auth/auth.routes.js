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

const router = express.Router();

// No authMiddleware on any of these — none of them require an existing
// session. Registration doesn't create an account until the code is
// confirmed (see auth.service.js), so verify/resend are identified by
// email, not a Bearer token — there is no token to send until the code
// is confirmed and the account actually exists.
router.post('/register', validateRegister, controller.register);
router.post('/login', validateLogin, controller.login);
router.post('/refresh', validateRefresh, controller.refresh);
router.post('/verify-email', validateVerifyEmail, controller.verifyEmail);
router.post('/resend-verification', validateResendVerification, controller.resendVerification);
router.post('/forgot-password', validateForgotPassword, controller.requestPasswordReset);
router.post('/reset-password', validateResetPassword, controller.resetPassword);

module.exports = router;

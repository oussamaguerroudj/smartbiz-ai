const asyncHandler = require('../../utils/asyncHandler');
const authService = require('./auth.service');

const register = asyncHandler(async (req, res) => {
  const result = await authService.register(req.body);
  res.status(201).json(result);
});

const login = asyncHandler(async (req, res) => {
  const result = await authService.login(req.body);
  res.status(200).json(result);
});

const refresh = asyncHandler(async (req, res) => {
  const result = await authService.refresh(req.body);
  res.status(200).json(result);
});

// Unauthenticated by design  -  see auth.service.js. Identified by email,
// not a token, because at this point (pending registration) no account
// or token exists yet.
const resendVerification = asyncHandler(async (req, res) => {
  await authService.resendVerification({
    email: req.body.email,
  });

  res.status(200).json({
    sent: true,
  });
});

const verifyEmail = asyncHandler(async (req, res) => {
  const result = await authService.verifyEmail({
    email: req.body.email,
    code: req.body.code,
  });

  // Same top-level shape as /register and /login: { user, accessToken,
  // refreshToken }  -  this is the moment the account (and its session)
  // first comes into existence.
  res.status(200).json(result);
});

const requestPasswordReset = asyncHandler(async (req, res) => {
  await authService.requestPasswordReset({
    email: req.body.email,
  });

  // Always 200 regardless of whether the email exists  -  see the
  // matching doc comment in auth.service.js.
  res.status(200).json({
    data: {
      sent: true,
    },
  });
});

const resetPassword = asyncHandler(async (req, res) => {
  await authService.resetPassword(req.body);

  res.status(200).json({
    data: {
      reset: true,
    },
  });
});

const getProfile = asyncHandler(async (req, res) => {
  const result = await authService.getProfile(req.user.id);
  res.status(200).json({ data: result });
});

const updateProfile = asyncHandler(async (req, res) => {
  const result = await authService.updateProfile(req.user.id, req.body || {});
  res.status(200).json({ data: result });
});

const changePassword = asyncHandler(async (req, res) => {
  const result = await authService.changePassword(req.user.id, req.body || {});
  res.status(200).json({ data: result });
});

const deleteAccount = asyncHandler(async (req, res) => {
  const result = await authService.deleteAccount(req.user.id, req.body || {});
  res.status(200).json({ data: result });
});

module.exports = {
  register,
  login,
  refresh,
  resendVerification,
  verifyEmail,
  requestPasswordReset,
  resetPassword,
  getProfile,
  updateProfile,
  changePassword,
  deleteAccount,
};
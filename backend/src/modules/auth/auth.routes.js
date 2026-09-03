const express = require('express');
const controller = require('./auth.controller');
const { validateRegister, validateLogin, validateRefresh } = require('./auth.validators');

const router = express.Router();

// No authMiddleware on these — they're how you GET a token in the first place.
router.post('/register', validateRegister, controller.register);
router.post('/login', validateLogin, controller.login);
router.post('/refresh', validateRefresh, controller.refresh);

module.exports = router;

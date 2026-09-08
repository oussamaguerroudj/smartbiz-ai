const express = require('express');
const controller = require('./appointments.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', controller.list);
router.post('/', controller.create);
router.put('/:id/status', controller.updateStatus);

module.exports = router;

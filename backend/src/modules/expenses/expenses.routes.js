const express = require('express');
const controller = require('./expenses.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', controller.list);
router.post('/', controller.create);
router.delete('/:id', controller.remove);

module.exports = router;

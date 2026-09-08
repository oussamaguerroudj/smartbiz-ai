const express = require('express');
const controller = require('./sales.controller');
const { validateCreateSale } = require('./sales.validators');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', controller.list);
router.get('/:id', controller.getOne);
router.post('/', validateCreateSale, controller.create);

module.exports = router;

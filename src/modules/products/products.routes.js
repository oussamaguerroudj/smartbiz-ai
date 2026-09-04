const express = require('express');
const controller = require('./products.controller');
const { validateCreate } = require('./products.validators');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware); // every route below requires a valid token

router.get('/', controller.list);
router.get('/:id', controller.getOne);
router.post('/', validateCreate, controller.create);
router.put('/:id', controller.update);
router.delete('/:id', controller.remove);

module.exports = router;

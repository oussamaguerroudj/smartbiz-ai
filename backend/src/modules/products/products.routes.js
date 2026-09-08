const express = require('express');
const controller = require('./products.controller');
const {
  validateCreate,
  validateUpdate,
} = require('./products.validators');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', controller.list);
// Two path segments (barcode/:code) vs one (:id) means these never
// actually collide, but keeping the more specific route first is the
// clearer convention.
router.get('/barcode/:code', controller.getByBarcode);
router.get('/:id', controller.getOne);
router.post('/', validateCreate, controller.create);
router.put('/:id', validateUpdate, controller.update);
router.delete('/:id', controller.remove);

module.exports = router;
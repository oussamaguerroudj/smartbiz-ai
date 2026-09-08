const express = require('express');
const controller = require('./employees.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', controller.list);
router.get('/:id', controller.getOne);
router.post('/', controller.create);
router.post('/:id/attendance', controller.markAttendance);
router.post('/:id/salary-adjustments', controller.addSalaryAdjustment);

module.exports = router;

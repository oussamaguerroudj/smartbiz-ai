const express = require('express');
const controller = require('./employees.controller');
const { authMiddleware } = require('../../middlewares/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', controller.list);
router.get('/:id', controller.getOne);
router.post('/', controller.create);
router.put('/:id', controller.update);
router.delete('/:id', controller.remove);
router.post('/:id/attendance', controller.markAttendance);
router.post('/:id/salary-adjustments', controller.addSalaryAdjustment);
router.post('/:id/pay-salary', controller.paySalary);
router.get('/:id/salaries', controller.getSalaryPayments);

module.exports = router;


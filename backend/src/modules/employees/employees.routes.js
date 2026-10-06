const express = require('express');
const controller = require('./employees.controller');
const { authMiddleware, requireRole } = require('../../middlewares/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', controller.list);
router.get('/:id', controller.getOne);
router.post('/', requireRole('owner'), controller.create);
router.put('/:id', requireRole('owner'), controller.update);
router.delete('/:id', requireRole('owner'), controller.remove);
router.post('/:id/attendance', controller.markAttendance);
router.post('/:id/salary-adjustments', requireRole('owner'), controller.addSalaryAdjustment);
router.post('/:id/pay-salary', requireRole('owner'), controller.paySalary);
router.get('/:id/salaries', controller.getSalaryPayments);

module.exports = router;


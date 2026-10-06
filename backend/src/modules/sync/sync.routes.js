const express = require('express');
const asyncHandler = require('../../utils/asyncHandler');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const salesService = require('../sales/sales.service');
const expensesService = require('../expenses/expenses.service');
const creditService = require('../credit/credit.service');
const employeesService = require('../employees/employees.service');
const appointmentsService = require('../appointments/appointments.service');
const suppliersRoutes = require('../suppliers/suppliers.routes');
const restaurantService = require('../restaurant/restaurant.service');
const { query } = require('../../config/db');

const ApiError = require('../../utils/ApiError');

const router = express.Router();
router.use(authMiddleware);

const MAX_SYNC_BATCH_SIZE = 100;

router.post(
  '/batch',
  asyncHandler(async (req, res) => {
    const { operations } = req.body || {};
    if (!Array.isArray(operations)) {
      throw ApiError.badRequest('operations array is required', 'VALIDATION_ERROR');
    }
    if (operations.length > MAX_SYNC_BATCH_SIZE) {
      throw ApiError.badRequest(
        `operations batch cannot exceed ${MAX_SYNC_BATCH_SIZE} items`,
        'VALIDATION_ERROR',
      );
    }

    const companyId = req.user.companyId;
    const userId = req.user.id;
    const userRole = req.user.role;
    const results = [];

    for (const op of operations) {
      const { id, clientTransactionId, entityType, operationType, payload = {} } = op || {};
      try {
        if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
          throw ApiError.badRequest('Invalid operation payload', 'VALIDATION_ERROR');
        }

        // Enforce owner-only RBAC on employee and payroll sync operations
        const isSalaryExpenseOp =
          entityType === 'expense' &&
          Boolean(
            payload.employeeId ||
              payload.salaryPeriod ||
              (typeof payload.category === 'string' && payload.category.trim().toLowerCase() === 'salary'),
          );
        if (
          (entityType === 'employee' || entityType === 'salary_payment' || isSalaryExpenseOp) &&
          userRole !== 'owner'
        ) {
          throw ApiError.forbidden('Only business owners can modify employees or payroll');
        }

        let serverResult = null;
        let serverId = null;

        if (entityType === 'sale' && (operationType === 'CREATE' || operationType === 'CREATE_SALE')) {
          serverResult = await salesService.createSale(companyId, {
            ...payload,
            clientTransactionId: clientTransactionId || id,
          });
          serverId = serverResult?.sale?.id;
        } else if (entityType === 'expense' && (operationType === 'CREATE' || operationType === 'CREATE_EXPENSE')) {
          serverResult = await expensesService.createExpense(companyId, {
            ...payload,
            clientId: clientTransactionId || id,
          });
          serverId = serverResult?.id;
        } else if (entityType === 'customer' && (operationType === 'CREATE' || operationType === 'CREATE_CUSTOMER')) {
          if (typeof payload.name !== 'string' || payload.name.trim().length === 0 || payload.name.trim().length > 255) {
            throw ApiError.badRequest('Customer name is required (1-255 chars)', 'VALIDATION_ERROR');
          }
          // Check if customer already exists by client_id
          const existingCust = await query(
            'SELECT * FROM customers WHERE company_id = $1 AND client_id = $2 AND deleted_at IS NULL',
            [companyId, clientTransactionId || id],
          );
          if (existingCust.rows[0]) {
            serverResult = existingCust.rows[0];
          } else {
            const ins = await query(
              'INSERT INTO customers (company_id, name, phone, address, client_id) VALUES ($1, $2, $3, $4, $5) RETURNING *',
              [
                companyId,
                payload.name.trim(),
                typeof payload.phone === 'string' ? payload.phone.trim() || null : null,
                typeof payload.address === 'string' ? payload.address.trim() || null : null,
                clientTransactionId || id,
              ],
            );
            serverResult = ins.rows[0];
          }
          serverId = serverResult?.id;
        } else if (entityType === 'payment' && (operationType === 'CREATE' || operationType === 'CREATE_PAYMENT')) {
          serverResult = await creditService.recordPayment(companyId, userId, {
            ...payload,
            clientId: clientTransactionId || id,
          });
          serverId = serverResult?.payment?.id;
        } else if (entityType === 'credit_purchase' && (operationType === 'CREATE' || operationType === 'CREATE_CREDIT_PURCHASE')) {
          serverResult = await creditService.createCreditPurchase(companyId, userId, {
            ...payload,
            clientId: clientTransactionId || id,
          });
          serverId = serverResult?.purchase?.id;
        } else if (entityType === 'employee' && (operationType === 'CREATE' || operationType === 'CREATE_EMPLOYEE')) {
          serverResult = await employeesService.createEmployee(companyId, {
            ...payload,
            clientId: clientTransactionId || id,
          });
          serverId = serverResult?.id;
        } else if (entityType === 'employee' && operationType === 'UPDATE') {
          serverResult = await employeesService.updateEmployee(companyId, op.entityId || payload.id, payload);
          serverId = serverResult?.id;
        } else if (entityType === 'employee' && operationType === 'DELETE') {
          serverResult = await employeesService.deleteEmployee(companyId, op.entityId || payload.id);
          serverId = serverResult?.id;
        } else if (entityType === 'salary_payment' && operationType === 'CREATE') {
          serverResult = await employeesService.paySalary(companyId, payload.employeeId || op.entityId, {
            ...payload,
            clientId: clientTransactionId || id,
          });
          serverId = serverResult?.salaryPayment?.id;
        } else if (entityType === 'appointment' && (operationType === 'CREATE' || operationType === 'CREATE_APPOINTMENT')) {
          serverResult = await appointmentsService.createAppointment(companyId, {
            ...payload,
            clientId: clientTransactionId || id,
          });
          serverId = serverResult?.id;
        } else if (entityType === 'appointment' && operationType === 'UPDATE_STATUS') {
          serverResult = await appointmentsService.updateStatus(companyId, payload.id || op.entityId, payload.status);
          serverId = serverResult?.id;
        } else if (entityType === 'supplier' && (operationType === 'CREATE' || operationType === 'CREATE_SUPPLIER')) {
          serverResult = await suppliersRoutes.createSupplier(companyId, {
            ...payload,
            clientId: clientTransactionId || id,
          });
          serverId = serverResult?.id;
        } else if (entityType === 'supplier' && operationType === 'UPDATE') {
          serverResult = await suppliersRoutes.updateSupplier(companyId, payload.id || op.entityId, payload);
          serverId = serverResult?.id;
        } else if (entityType === 'supplier' && operationType === 'DELETE') {
          serverResult = await suppliersRoutes.deleteSupplier(companyId, op.entityId || payload.id);
          serverId = serverResult?.id;
        } else if (entityType === 'restaurant_order' && operationType === 'CREATE') {
          serverResult = await restaurantService.createOrder(companyId, payload);
          serverId = serverResult?.id;
        } else if (entityType === 'restaurant_order' && operationType === 'UPDATE') {
          serverResult = await restaurantService.updateOrder(companyId, op.entityId || payload.id, payload);
          serverId = serverResult?.id;
        } else if (entityType === 'restaurant_order' && operationType === 'UPDATE_STATUS') {
          serverResult = await restaurantService.updateOrderStatus(companyId, op.entityId || payload.id, payload.status);
          serverId = serverResult?.id;
        } else if (entityType === 'restaurant_order' && operationType === 'RECORD_PAYMENT') {
          serverResult = await restaurantService.recordPayment(companyId, op.entityId || payload.orderId, payload);
          serverId = serverResult?.order?.id;
        } else {
          throw ApiError.badRequest(`Unsupported operation: ${entityType}:${operationType}`, 'UNSUPPORTED_OPERATION');
        }

        results.push({
          id,
          clientTransactionId,
          status: 'synced',
          serverId,
          data: serverResult,
        });
      } catch (err) {
        // Individual error does NOT abort the remaining batch (partial sync support!)
        const safeMessage =
          err instanceof ApiError
            ? err.message
            : 'Operation failed due to invalid data or server error';
        results.push({
          id,
          clientTransactionId,
          status: 'failed',
          error: safeMessage,
        });
      }
    }

    res.json({ results });
  }),
);

module.exports = router;

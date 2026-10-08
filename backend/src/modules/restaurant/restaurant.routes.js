const express = require('express');
const controller = require('./restaurant.controller');
const {
  validateCreateTable,
  validateCreateMenuItem,
  validateCreateOrder,
  validateCreateReservation,
  validateRecordPayment,
  validateCreateInventoryItem,
  validateAdjustInventory,
} = require('./restaurant.validators');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const { requireBusinessType } = require('../../middlewares/businessType.middleware');

const router = express.Router();

router.use(authMiddleware);
// Dashboard-family simplification: 'cafe' is a legacy/compatibility
// business_type value now folded into the Restaurant family (mobile
// picker only offers 'restaurant' to new signups  -  see
// business_type_screen.dart's kSelectableBusinessTypes and
// backend/SPECIALIZED_MODULES.md).
router.use(requireBusinessType('restaurant', 'cafe'));

router.get('/dashboard', controller.getDashboard);

router.post('/tables', validateCreateTable, controller.createTable);
router.get('/tables', controller.listTables);
router.patch('/tables/:id/status', controller.updateTableStatus);
router.put('/tables/:id', controller.updateTable);
router.patch('/tables/:id', controller.updateTable);
router.delete('/tables/:id', controller.deleteTable);

router.post('/menu-items', validateCreateMenuItem, controller.createMenuItem);
router.get('/menu-items', controller.listMenuItems);
router.put('/menu-items/:id', controller.updateMenuItem);
router.patch('/menu-items/:id', controller.updateMenuItem);
router.patch('/menu-items/:id/availability', controller.setMenuItemAvailability);
router.patch('/menu-items/:id/image', controller.setMenuItemImage);
router.get('/menu-items/:id/ingredients', controller.getMenuItemIngredients);
router.put('/menu-items/:id/ingredients', controller.setMenuItemIngredients);
router.delete('/menu-items/:id', controller.deleteMenuItem);

router.post('/orders', validateCreateOrder, controller.createOrder);
router.get('/orders', controller.listOrders);
router.get('/orders/active', controller.getActiveOrders);
router.get('/orders/:id', controller.getOrderDetail);
router.put('/orders/:id', controller.updateOrder);
router.patch('/orders/:id', controller.updateOrder);
router.patch('/orders/:id/status', controller.updateOrderStatus);
router.post('/orders/:id/payments', validateRecordPayment, controller.recordPayment);
router.post('/orders/:id/refund', controller.refundOrder);
router.get('/orders/:id/invoice', controller.getOrderInvoice);
router.get('/orders/:id/invoice/pdf', controller.getOrderInvoicePdf);

router.post('/reservations', validateCreateReservation, controller.createReservation);
router.get('/reservations', controller.listReservations);
router.patch('/reservations/:id/status', controller.updateReservationStatus);
router.put('/reservations/:id', controller.updateReservation);
router.patch('/reservations/:id', controller.updateReservation);
router.delete('/reservations/:id', controller.deleteReservation);

router.post('/inventory', validateCreateInventoryItem, controller.createInventoryItem);
router.get('/inventory', controller.listInventoryItems);
router.get('/inventory/:id', controller.getInventoryItem);
router.patch('/inventory/:id', controller.updateInventoryItem);
router.delete('/inventory/:id', controller.archiveInventoryItem);
router.post('/inventory/:id/adjust', validateAdjustInventory, controller.adjustInventoryQuantity);

module.exports = router;

const service = require('../restaurant.service');
const repo = require('../restaurant.repository');

jest.mock('../restaurant.repository');

repo.VALID_ORDER_STATUSES = ['pending', 'preparing', 'ready', 'served', 'completed', 'cancelled'];

describe('Restaurant Order Lifecycle & Payment Guard Tests', () => {
  const companyId = '00000000-0000-0000-0000-000000000001';
  const orderId = '11111111-1111-1111-1111-111111111111';

  beforeEach(() => {
    repo.VALID_ORDER_STATUSES = ['pending', 'preparing', 'ready', 'served', 'completed', 'cancelled'];
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('updateOrderStatus - Completion Rules', () => {
    it('rejects COMPLETED when order preparation is not ready yet (pending)', async () => {
      repo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'pending',
        payment_status: 'paid',
        total_amount: 1500,
        amount_paid: 1500,
      });

      await expect(service.updateOrderStatus(companyId, orderId, 'completed'))
        .rejects
        .toMatchObject({
          message: 'Order is not ready yet',
          code: 'ORDER_NOT_READY',
          statusCode: 400,
        });

      expect(repo.updateOrderStatus).not.toHaveBeenCalled();
    });

    it('rejects COMPLETED when order preparation is preparing', async () => {
      repo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'preparing',
        payment_status: 'paid',
        total_amount: 1500,
        amount_paid: 1500,
      });

      await expect(service.updateOrderStatus(companyId, orderId, 'completed'))
        .rejects
        .toMatchObject({
          message: 'Order is not ready yet',
          code: 'ORDER_NOT_READY',
          statusCode: 400,
        });

      expect(repo.updateOrderStatus).not.toHaveBeenCalled();
    });

    it('rejects COMPLETED when order is READY but payment_status is UNPAID', async () => {
      repo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'ready',
        payment_status: 'unpaid',
        total_amount: 1850,
        amount_paid: 0,
      });

      await expect(service.updateOrderStatus(companyId, orderId, 'completed'))
        .rejects
        .toMatchObject({
          message: 'Order payment is required before completion',
          code: 'ORDER_PAYMENT_REQUIRED',
          statusCode: 400,
        });

      expect(repo.updateOrderStatus).not.toHaveBeenCalled();
    });

    it('rejects COMPLETED when order is SERVED but payment_status is PARTIALLY_PAID', async () => {
      repo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'served',
        payment_status: 'partially_paid',
        total_amount: 1850,
        amount_paid: 1000,
      });

      await expect(service.updateOrderStatus(companyId, orderId, 'completed'))
        .rejects
        .toMatchObject({
          message: 'Order payment is required before completion',
          code: 'ORDER_PAYMENT_REQUIRED',
          statusCode: 400,
        });

      expect(repo.updateOrderStatus).not.toHaveBeenCalled();
    });

    it('allows COMPLETED when order is READY and fully PAID', async () => {
      repo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'ready',
        payment_status: 'paid',
        total_amount: 1850,
        amount_paid: 1850,
      });
      repo.updateOrderStatus.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'completed',
        payment_status: 'paid',
        total_amount: 1850,
        amount_paid: 1850,
      });

      const res = await service.updateOrderStatus(companyId, orderId, 'completed');
      expect(res.status).toBe('completed');
      expect(repo.updateOrderStatus).toHaveBeenCalledWith(companyId, orderId, 'completed');
    });

    it('allows COMPLETED when order is SERVED and fully PAID', async () => {
      repo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'served',
        payment_status: 'paid',
        total_amount: 2400,
        amount_paid: 2400,
      });
      repo.updateOrderStatus.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'completed',
        payment_status: 'paid',
        total_amount: 2400,
        amount_paid: 2400,
      });

      const res = await service.updateOrderStatus(companyId, orderId, 'completed');
      expect(res.status).toBe('completed');
      expect(repo.updateOrderStatus).toHaveBeenCalledWith(companyId, orderId, 'completed');
    });
  });

  describe('recordPayment - Duplicate Payment Protection', () => {
    it('throws 409 ORDER_ALREADY_PAID when order is already fully paid', async () => {
      repo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        status: 'ready',
        payment_status: 'paid',
        total_amount: 1850,
        amount_paid: 1850,
      });
      const duplicateErr = new Error('This order is already fully paid');
      duplicateErr.code = 'ORDER_ALREADY_PAID';
      repo.recordPayment.mockRejectedValue(duplicateErr);

      await expect(service.recordPayment(companyId, orderId, { amount: 500 }))
        .rejects
        .toMatchObject({
          message: 'This order is already fully paid',
          code: 'ORDER_ALREADY_PAID',
          statusCode: 409,
        });
    });
  });

  describe('createOrder - With Customer and Order Type', () => {
    it('creates order with customer_name and order_type', async () => {
      repo.findTableById.mockResolvedValue({ id: 'table-1', name: 'Table 1' });
      repo.findMenuItemById.mockResolvedValue({
        id: 'menu-1',
        name: 'Pizza Margherita',
        price: 900,
      });
      repo.createOrder.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        order_number: 1,
        customer_name: 'Client 1',
        order_type: 'dine_in',
        status: 'pending',
        payment_status: 'unpaid',
        total_amount: 1800,
      });

      const res = await service.createOrder(companyId, {
        customerName: 'Client 1',
        orderType: 'dine_in',
        tableId: 'table-1',
        items: [{ menuItemId: 'menu-1', quantity: 2 }],
      });

      expect(res.customer_name).toBe('Client 1');
      expect(repo.createOrder).toHaveBeenCalledWith(
        companyId,
        expect.objectContaining({
          customerName: 'Client 1',
          orderType: 'dine_in',
          tableId: 'table-1',
          items: [
            expect.objectContaining({
              name: 'Pizza Margherita',
              unitPrice: 900,
              quantity: 2,
            }),
          ],
        }),
      );
    });
  });
});

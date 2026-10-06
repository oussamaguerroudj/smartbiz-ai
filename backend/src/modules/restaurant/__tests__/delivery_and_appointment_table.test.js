const restaurantService = require('../restaurant.service');
const restaurantRepo = require('../restaurant.repository');
const appointmentsService = require('../../appointments/appointments.service');
const appointmentsRepo = require('../../appointments/appointments.repository');

jest.mock('../restaurant.repository');
jest.mock('../../appointments/appointments.repository');

describe('Delivery Order Phone/Address & Optional Appointment Table Tests', () => {
  const companyId = '00000000-0000-0000-0000-000000000001';
  const orderId = '11111111-1111-1111-1111-111111111111';
  const appointmentId = '22222222-2222-2222-2222-222222222222';
  const tableId = '33333333-3333-3333-3333-333333333333';

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Delivery Order Phone & Address', () => {
    it('creates a delivery order passing customerPhone and deliveryAddress to repo', async () => {
      restaurantRepo.createOrder.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        order_number: 101,
        status: 'pending',
        order_type: 'delivery',
        customer_name: 'Karim Bensalem',
        customer_phone: '0555123456',
        delivery_address: '14 Rue Didouche Mourad, Alger',
        total_amount: 2500,
        amount_paid: 0,
        payment_status: 'unpaid',
      });

      const orderData = {
        orderType: 'delivery',
        customerName: 'Karim Bensalem',
        customerPhone: '0555123456',
        deliveryAddress: '14 Rue Didouche Mourad, Alger',
        items: [
          { name: 'Pizza Royale', unitPrice: 1200, quantity: 2 },
          { name: 'Coca-Cola 1L', unitPrice: 100, quantity: 1 },
        ],
      };

      const result = await restaurantService.createOrder(companyId, orderData);

      expect(restaurantRepo.createOrder).toHaveBeenCalledWith(companyId, expect.objectContaining({
        orderType: 'delivery',
        customerName: 'Karim Bensalem',
        customerPhone: '0555123456',
        deliveryAddress: '14 Rue Didouche Mourad, Alger',
      }));
      expect(result.customer_phone).toBe('0555123456');
      expect(result.delivery_address).toBe('14 Rue Didouche Mourad, Alger');
      expect(result.order_type).toBe('delivery');
    });

    it('getOrderInvoice includes customerName, customerPhone, deliveryAddress, orderType', async () => {
      restaurantRepo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        order_number: 101,
        status: 'ready',
        order_type: 'delivery',
        customer_name: 'Karim Bensalem',
        customer_phone: '0555123456',
        delivery_address: '14 Rue Didouche Mourad, Alger',
        total_amount: 2500,
        amount_paid: 2500,
        payment_status: 'paid',
        created_at: new Date('2026-10-06T12:00:00Z'),
      });

      restaurantRepo.findOrderItems.mockResolvedValue([
        { item_name: 'Pizza Royale', unit_price: '1200', quantity: 2, subtotal: '2400' },
        { item_name: 'Coca-Cola 1L', unit_price: '100', quantity: 1, subtotal: '100' },
      ]);

      const invoice = await restaurantService.getOrderInvoice(companyId, orderId);

      expect(invoice.customerName).toBe('Karim Bensalem');
      expect(invoice.customerPhone).toBe('0555123456');
      expect(invoice.deliveryAddress).toBe('14 Rue Didouche Mourad, Alger');
      expect(invoice.orderType).toBe('delivery');
      expect(invoice.totalAmount).toBe(2500);
      expect(invoice.paymentStatus).toBe('paid');
    });

    it('accepts any plain text phone string without format restrictions (e.g. 123, spaces, +213)', async () => {
      restaurantRepo.createOrder.mockResolvedValue({
        id: orderId,
        customer_phone: '123',
        delivery_address: 'Algiers',
      });

      const res = await restaurantService.createOrder(companyId, {
        orderType: 'delivery',
        customerPhone: '123',
        deliveryAddress: 'Algiers',
        items: [{ name: 'Bread', unitPrice: 50, quantity: 1 }],
      });

      expect(res.customer_phone).toBe('123');
      expect(restaurantRepo.createOrder).toHaveBeenCalledWith(
        companyId,
        expect.objectContaining({ customerPhone: '123' })
      );
    });

    it('updates an existing delivery order phone from 0551234567 to 0669876543', async () => {
      restaurantRepo.findOrderById.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        customer_name: 'Test Client',
        customer_phone: '0551234567',
        delivery_address: 'Test Address',
      });

      restaurantRepo.updateOrder.mockResolvedValue({
        id: orderId,
        company_id: companyId,
        customer_name: 'Test Client',
        customer_phone: '0669876543',
        delivery_address: 'Test Address',
      });

      const updated = await restaurantService.updateOrder(companyId, orderId, {
        customerPhone: '0669876543',
      });

      expect(restaurantRepo.updateOrder).toHaveBeenCalledWith(companyId, orderId, {
        customerPhone: '0669876543',
      });
      expect(updated.customer_phone).toBe('0669876543');
    });
  });

  describe('Optional Table Assignment for Appointments & Reservations', () => {
    it('creates an appointment with optional tableId', async () => {
      appointmentsRepo.create.mockResolvedValue({
        id: appointmentId,
        company_id: companyId,
        title: 'Dr. Amina Consultation',
        scheduled_at: '2026-10-06T15:00:00Z',
        table_id: tableId,
        status: 'scheduled',
      });

      const appointment = await appointmentsService.createAppointment(companyId, {
        title: 'Dr. Amina Consultation',
        scheduledAt: '2026-10-06T15:00:00Z',
        tableId,
      });

      expect(appointmentsRepo.create).toHaveBeenCalledWith(companyId, expect.objectContaining({
        title: 'Dr. Amina Consultation',
        scheduledAt: '2026-10-06T15:00:00Z',
        tableId,
      }));
      expect(appointment.table_id).toBe(tableId);
    });

    it('creates an appointment without tableId (strictly optional / null)', async () => {
      appointmentsRepo.create.mockResolvedValue({
        id: appointmentId,
        company_id: companyId,
        title: 'Walk-in Client',
        scheduled_at: '2026-10-06T16:00:00Z',
        table_id: null,
        status: 'scheduled',
      });

      const appointment = await appointmentsService.createAppointment(companyId, {
        title: 'Walk-in Client',
        scheduledAt: '2026-10-06T16:00:00Z',
      });

      expect(appointmentsRepo.create).toHaveBeenCalledWith(companyId, expect.objectContaining({
        title: 'Walk-in Client',
      }));
      expect(appointment.table_id).toBeNull();
    });

    it('updates an appointment to clear tableId (set to null)', async () => {
      appointmentsRepo.update.mockResolvedValue({
        id: appointmentId,
        company_id: companyId,
        title: 'Updated Client',
        table_id: null,
      });

      const updated = await appointmentsService.updateAppointment(companyId, appointmentId, {
        tableId: null,
      });

      expect(appointmentsRepo.update).toHaveBeenCalledWith(companyId, appointmentId, {
        tableId: null,
      });
      expect(updated.table_id).toBeNull();
    });

    it('updates a reservation allowing clearing tableId', async () => {
      restaurantRepo.updateReservation.mockResolvedValue({
        id: 'res-1',
        customer_name: 'Samir',
        table_id: null,
      });

      const updated = await restaurantService.updateReservation(companyId, 'res-1', {
        tableId: null,
      });

      expect(restaurantRepo.updateReservation).toHaveBeenCalledWith(companyId, 'res-1', expect.objectContaining({
        tableId: null,
      }));
      expect(updated.table_id).toBeNull();
    });
  });
});

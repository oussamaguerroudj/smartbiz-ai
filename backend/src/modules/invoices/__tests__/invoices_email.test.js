const invoicesService = require('../invoices.service');
const repo = require('../invoices.repository');
const { query } = require('../../../config/db');
const { sendMail } = require('../../../utils/email');

jest.mock('../invoices.repository');
jest.mock('../../../config/db');
jest.mock('../../../utils/email');

describe('Invoices Email Delivery', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects invalid recipient email address', async () => {
    await expect(invoicesService.emailInvoice('comp-1', 'inv-1', 'invalid-email'))
      .rejects.toThrow('Valid recipient email address is required');

    await expect(invoicesService.emailInvoice('comp-1', 'inv-1', ''))
      .rejects.toThrow('Valid recipient email address is required');
  });

  it('successfully generates PDF and sends email with attachment', async () => {
    query.mockResolvedValueOnce({
      rows: [{ name: 'Test Pharmacie', phone: '0555001122', address: 'Alger' }],
    });

    repo.findById.mockResolvedValueOnce({
      id: 'inv-1',
      invoice_number: 'INV-2026-001',
      status: 'paid',
      total: 3500,
      subtotal: 3500,
      discount: 0,
      created_at: new Date('2026-01-15'),
      customer_name: 'Dr. Amine',
      customer_phone: '0555123456',
      items: [
        { product_name: 'Paracétamol 500mg', quantity: 2, unit_price: 150, line_total: 300 },
        { product_name: 'Augmentin 1g', quantity: 1, unit_price: 3200, line_total: 3200 },
      ],
    });

    sendMail.mockResolvedValueOnce({ messageId: 'msg-test-123' });

    const result = await invoicesService.emailInvoice('comp-1', 'inv-1', 'client@example.com');

    expect(result).toEqual({ ok: true, recipient: 'client@example.com' });
    expect(sendMail).toHaveBeenCalledTimes(1);
    const mailArgs = sendMail.mock.calls[0][0];
    expect(mailArgs.to).toBe('client@example.com');
    expect(mailArgs.subject).toContain('INV-2026-001');
    expect(mailArgs.subject).toContain('Test Pharmacie');
    expect(mailArgs.attachments).toBeDefined();
    expect(mailArgs.attachments.length).toBe(1);
    expect(mailArgs.attachments[0].name).toBe('INV-2026-001.pdf');
    expect(typeof mailArgs.attachments[0].content).toBe('string');
  });
});

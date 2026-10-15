const { findById } = require('../suppliers.routes');
const { query } = require('../../../config/db');

jest.mock('../../../config/db');

describe('Suppliers Service - Profile & History', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('throws 404 when supplier does not exist', async () => {
    query.mockResolvedValueOnce({ rows: [] });

    await expect(findById('comp-1', 'supp-nonexistent')).rejects.toThrow('Supplier not found');
    expect(query).toHaveBeenCalledTimes(1);
  });

  it('returns supplier details with products supplied and calculated inventory totals', async () => {
    // 1. Supplier query
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'supp-1',
          name: 'Laboratoire Biocare',
          phone: '0550112233',
          address: 'Zone Industrielle Oued Smar, Alger',
          products_supplied: 2,
        },
      ],
    });

    // 2. Products query
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'prod-1',
          name: 'Paracétamol 500mg',
          category: 'Médicaments',
          barcode: '6131112223334',
          purchase_price: 120.0,
          selling_price: 150.0,
          quantity: 50,
          expiration_date: '2026-12-31',
        },
        {
          id: 'prod-2',
          name: 'Amoxicilline 500mg',
          category: 'Antibiotiques',
          barcode: '6134445556667',
          purchase_price: 300.0,
          selling_price: 400.0,
          quantity: 20,
          expiration_date: '2027-06-30',
        },
      ],
    });

    const result = await findById('comp-1', 'supp-1');

    expect(result.id).toBe('supp-1');
    expect(result.name).toBe('Laboratoire Biocare');
    expect(result.products).toHaveLength(2);
    // Total stock units: 50 + 20 = 70
    expect(result.total_stock_units).toBe(70);
    // Total purchase value: (120 * 50) + (300 * 20) = 6000 + 6000 = 12000
    expect(result.total_purchase_value).toBe(12000);
  });
});

const repo = require('../products.repository');
const { query } = require('../../../config/db');

jest.mock('../../../config/db');

describe('Products Repository - Pharmacy & Batch Tracking', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('persists dosage, form, active_ingredient, and batch_number on create', async () => {
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'prod-pharm-1',
          company_id: 'comp-1',
          name: 'Amoxicilline 500mg Gélule',
          purchase_price: '200.00',
          selling_price: '300.00',
          quantity: 40,
          dosage: '500mg',
          form: 'Gélule',
          active_ingredient: 'Amoxicilline trihydratée',
          batch_number: 'BATCH-2026-X1',
        },
      ],
    });

    const result = await repo.create('comp-1', {
      name: 'Amoxicilline 500mg Gélule',
      purchasePrice: 200,
      sellingPrice: 300,
      quantity: 40,
      dosage: '500mg',
      form: 'Gélule',
      activeIngredient: 'Amoxicilline trihydratée',
      batchNumber: 'BATCH-2026-X1',
    });

    expect(result.id).toBe('prod-pharm-1');
    expect(result.dosage).toBe('500mg');
    expect(result.form).toBe('Gélule');
    expect(result.active_ingredient).toBe('Amoxicilline trihydratée');
    expect(result.batch_number).toBe('BATCH-2026-X1');

    expect(query).toHaveBeenCalledTimes(1);
    const sql = query.mock.calls[0][0];
    const params = query.mock.calls[0][1];

    expect(sql).toContain('dosage');
    expect(sql).toContain('form');
    expect(sql).toContain('active_ingredient');
    expect(sql).toContain('batch_number');

    expect(params).toContain('500mg');
    expect(params).toContain('Gélule');
    expect(params).toContain('Amoxicilline trihydratée');
    expect(params).toContain('BATCH-2026-X1');
  });

  it('updates dosage, form, active_ingredient, and batch_number on update', async () => {
    query.mockResolvedValueOnce({
      rows: [
        {
          id: 'prod-pharm-1',
          company_id: 'comp-1',
          name: 'Amoxicilline 1g',
          dosage: '1g',
          form: 'Comprimé',
          active_ingredient: 'Amoxicilline',
          batch_number: 'BATCH-2026-Y2',
        },
      ],
    });

    const result = await repo.update('comp-1', 'prod-pharm-1', {
      name: 'Amoxicilline 1g',
      dosage: '1g',
      form: 'Comprimé',
      activeIngredient: 'Amoxicilline',
      batchNumber: 'BATCH-2026-Y2',
    });

    expect(result.dosage).toBe('1g');
    expect(result.form).toBe('Comprimé');
    expect(query).toHaveBeenCalledTimes(1);
    const sql = query.mock.calls[0][0];
    const params = query.mock.calls[0][1];

    expect(sql).toContain('dosage = COALESCE($15, dosage)');
    expect(sql).toContain('form = COALESCE($16, form)');
    expect(sql).toContain('active_ingredient = COALESCE($17, active_ingredient)');
    expect(sql).toContain('batch_number = COALESCE($18, batch_number)');

    expect(params).toContain('1g');
    expect(params).toContain('Comprimé');
  });
});

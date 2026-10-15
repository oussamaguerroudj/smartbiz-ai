const { createSupplier } = require('../suppliers.routes');
const { query, withTransaction } = require('../../../config/db');

jest.mock('../../../config/db', () => {
  const actualDb = {
    query: jest.fn(),
    withTransaction: jest.fn((cb) => cb({ query: actualDb.query })),
  };
  return actualDb;
});

describe('Supplier Creation Idempotency & Concurrency Safety', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    query.mockReset();
  });

  it('prevents duplicate supplier creation for the same company by returning existing record', async () => {
    const existingSupplier = {
      id: 'supp-existing-1',
      company_id: 'comp-1',
      name: 'SARL Agro Alimentaire',
      phone: '0555123456',
      address: 'Alger',
      products_supplied: 5,
    };

    // 1. Lock query
    query.mockResolvedValueOnce({ rows: [] });
    // 2. existingByName query finds existing record
    query.mockResolvedValueOnce({ rows: [existingSupplier] });
    // 3. findById supplier query
    query.mockResolvedValueOnce({ rows: [existingSupplier] });
    // 4. findById products query
    query.mockResolvedValueOnce({ rows: [] });

    const result = await createSupplier('comp-1', {
      name: '  sarl agro alimentaire  ',
      phone: '0555123456',
    });

    expect(result.id).toBe('supp-existing-1');
    expect(result.name).toBe('SARL Agro Alimentaire');
    // Ensure no INSERT query was executed
    const insertCall = query.mock.calls.find((call) =>
      typeof call[0] === 'string' && call[0].includes('INSERT INTO suppliers')
    );
    expect(insertCall).toBeUndefined();
  });

  it('allows different companies to create suppliers with the identical name independently', async () => {
    const newSupplierComp2 = {
      id: 'supp-comp2-1',
      company_id: 'comp-2',
      name: 'SARL Agro Alimentaire',
      phone: '0666000000',
      address: 'Oran',
    };

    // Comp 2: Lock query
    query.mockResolvedValueOnce({ rows: [] });
    // Comp 2: existingByName returns empty (no supplier in comp-2)
    query.mockResolvedValueOnce({ rows: [] });
    // Comp 2: INSERT succeeds
    query.mockResolvedValueOnce({ rows: [newSupplierComp2] });

    const result = await createSupplier('comp-2', {
      name: 'SARL Agro Alimentaire',
      phone: '0666000000',
    });

    expect(result.id).toBe('supp-comp2-1');
    expect(result.company_id).toBe('comp-2');
  });

  it('creates distinct records for similar but non-identical supplier names', async () => {
    const supplier1 = {
      id: 'supp-blida-1',
      company_id: 'comp-1',
      name: 'Grossiste Blida',
      phone: '0550111111',
    };
    const supplier2 = {
      id: 'supp-blida-centre',
      company_id: 'comp-1',
      name: 'Grossiste Blida Centre',
      phone: '0550222222',
    };

    // Call 1
    query.mockResolvedValueOnce({ rows: [] }); // Lock
    query.mockResolvedValueOnce({ rows: [] }); // Check
    query.mockResolvedValueOnce({ rows: [supplier1] }); // Insert

    const res1 = await createSupplier('comp-1', { name: 'Grossiste Blida' });
    expect(res1.id).toBe('supp-blida-1');

    // Call 2
    query.mockResolvedValueOnce({ rows: [] }); // Lock
    query.mockResolvedValueOnce({ rows: [] }); // Check
    query.mockResolvedValueOnce({ rows: [supplier2] }); // Insert

    const res2 = await createSupplier('comp-1', { name: 'Grossiste Blida Centre' });
    expect(res2.id).toBe('supp-blida-centre');
    expect(res2.id).not.toBe(res1.id);
  });
});

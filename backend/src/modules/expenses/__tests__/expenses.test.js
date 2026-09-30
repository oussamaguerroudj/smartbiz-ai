const service = require('../expenses.service');
const repo = require('../expenses.repository');

jest.mock('../expenses.repository');

describe('Expenses Service & Duplicate Salary Protection Tests', () => {
  const companyId = '00000000-0000-0000-0000-000000000001';
  const employeeId = '11111111-1111-1111-1111-111111111111';

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('createExpense', () => {
    it('creates regular operating expense without duplicate warnings', async () => {
      repo.create.mockResolvedValue({
        id: 'exp-1',
        category: 'Rent',
        amount: 20000,
        expense_date: '2026-09-05',
      });

      const res = await service.createExpense(companyId, {
        category: 'Rent',
        amount: 20000,
        expenseDate: '2026-09-05',
      });

      expect(res.category).toBe('Rent');
      expect(res.amount).toBe(20000);
      expect(repo.create).toHaveBeenCalledWith(companyId, expect.objectContaining({
        category: 'Rent',
        amount: 20000,
        expenseDate: '2026-09-05',
      }));
    });

    it('creates salary payment record with employee, salary_period, duration', async () => {
      repo.checkDuplicateSalary.mockResolvedValue(null);
      repo.create.mockResolvedValue({
        id: 'exp-sal-1',
        category: 'Salary',
        amount: 30000,
        employee_id: employeeId,
        salary_period: '2026-09',
        duration: '1 month',
        expense_date: '2026-09-30',
      });

      const res = await service.createExpense(companyId, {
        category: 'Salary',
        amount: 30000,
        employeeId,
        salaryPeriod: '2026-09',
        duration: '1 month',
        expenseDate: '2026-09-30',
      });

      expect(res.salary_period).toBe('2026-09');
      expect(res.employee_id).toBe(employeeId);
      expect(repo.checkDuplicateSalary).toHaveBeenCalledWith(companyId, employeeId, '2026-09');
    });

    it('rejects duplicate salary payment for same employee & salary period if not confirmed', async () => {
      repo.checkDuplicateSalary.mockResolvedValue({
        id: 'existing-sal-1',
        amount: 30000,
        expense_date: '2026-09-30',
        salary_period: '2026-09',
      });

      await expect(
        service.createExpense(companyId, {
          category: 'Salary',
          amount: 30000,
          employeeId,
          salaryPeriod: '2026-09',
          duration: '1 month',
          expenseDate: '2026-09-30',
          confirmedDuplicate: false,
        })
      ).rejects.toMatchObject({
        statusCode: 409,
        code: 'DUPLICATE_SALARY_PAYMENT',
      });

      expect(repo.create).not.toHaveBeenCalled();
    });

    it('allows duplicate salary payment when explicitly confirmed by user', async () => {
      repo.checkDuplicateSalary.mockResolvedValue({
        id: 'existing-sal-1',
        amount: 30000,
        expense_date: '2026-09-30',
        salary_period: '2026-09',
      });

      repo.create.mockResolvedValue({
        id: 'exp-sal-2',
        category: 'Salary',
        amount: 30000,
        employee_id: employeeId,
        salary_period: '2026-09',
        duration: '1 month',
        expense_date: '2026-09-30',
      });

      const res = await service.createExpense(companyId, {
        category: 'Salary',
        amount: 30000,
        employeeId,
        salaryPeriod: '2026-09',
        duration: '1 month',
        expenseDate: '2026-09-30',
        confirmedDuplicate: true,
      });

      expect(res.id).toBe('exp-sal-2');
      expect(repo.create).toHaveBeenCalled();
    });
  });
});

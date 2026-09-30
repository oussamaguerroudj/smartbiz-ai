-- 027_financial_actual_transactions.sql
-- Fixes financial calculation architecture:
-- Stores actual salary transactions as first-class expense records.
-- Records employee, salary_period, duration on expense transactions.
-- Reports calculate totals strictly by summing actual transactions.

ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS salary_period VARCHAR(30),
  ADD COLUMN IF NOT EXISTS duration VARCHAR(50) DEFAULT '1 month';

CREATE INDEX IF NOT EXISTS ix_expenses_employee_period
  ON expenses (company_id, employee_id, salary_period)
  WHERE employee_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_expenses_date_company
  ON expenses (company_id, expense_date);

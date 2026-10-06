-- 028_add_offline_sync_support.sql
-- Enables idempotent offline synchronization across sales, expenses, customers, and credit payments.

ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS client_transaction_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS ux_sales_company_client_tx
  ON sales (company_id, client_transaction_id)
  WHERE client_transaction_id IS NOT NULL;

ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS client_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS ux_expenses_company_client_id
  ON expenses (company_id, client_id)
  WHERE client_id IS NOT NULL;

ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS client_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS ux_customers_company_client_id
  ON customers (company_id, client_id)
  WHERE client_id IS NOT NULL;

ALTER TABLE credit_payments
  ADD COLUMN IF NOT EXISTS client_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS ux_credit_payments_company_client_id
  ON credit_payments (company_id, client_id)
  WHERE client_id IS NOT NULL;

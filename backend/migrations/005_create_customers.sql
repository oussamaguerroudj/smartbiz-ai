-- 005_create_customers.sql
-- Customer / patient records with outstanding balance (Ch. 21.1).
-- Relabeled to "Patients" in UI for clinic business_type — same table.

CREATE TABLE customers (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name           VARCHAR(120) NOT NULL,
  phone          VARCHAR(30),
  address        VARCHAR(255),
  balance_due    NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ
);

CREATE INDEX ix_customers_company_id ON customers (company_id);

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

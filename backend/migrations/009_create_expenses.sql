-- 009_create_expenses.sql
-- Recorded expenses (Ch. 20).

CREATE TABLE expenses (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  category       VARCHAR(60) NOT NULL, -- Electricity, Transport, Internet, Rent, Supplies, Other
  description    VARCHAR(255),
  amount         NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  expense_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ
);

CREATE INDEX ix_expenses_company_id ON expenses (company_id);
CREATE INDEX ix_expenses_company_date ON expenses (company_id, expense_date);

CREATE TRIGGER trg_expenses_updated_at
  BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

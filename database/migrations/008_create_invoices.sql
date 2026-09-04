-- 008_create_invoices.sql
-- One invoice per sale (Ch. 13, 14). invoice_number is unique per company
-- (not globally) so each tenant gets a clean INV-1, INV-2... sequence.

CREATE TYPE invoice_status_enum AS ENUM ('paid', 'unpaid');

CREATE TABLE invoices (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id       UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  sale_id          UUID NOT NULL UNIQUE REFERENCES sales(id) ON DELETE CASCADE,
  invoice_number   VARCHAR(30) NOT NULL,
  status           invoice_status_enum NOT NULL DEFAULT 'unpaid',
  pdf_url          TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ux_invoices_company_number ON invoices (company_id, invoice_number);
CREATE INDEX ix_invoices_company_id ON invoices (company_id);

CREATE TRIGGER trg_invoices_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

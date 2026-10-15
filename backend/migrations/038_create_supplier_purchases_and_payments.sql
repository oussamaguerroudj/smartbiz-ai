-- 038_create_supplier_purchases_and_payments.sql
-- Complete supplier purchase invoices, line items, and accounts-payable ledger.
-- Preserves existing supplier contacts, catalog linkages, and business isolation.

CREATE TABLE IF NOT EXISTS supplier_purchases (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  supplier_id           UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  invoice_number        VARCHAR(100),
  purchase_date         TIMESTAMPTZ NOT NULL DEFAULT now(),
  total_amount          NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
  amount_paid           NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (amount_paid >= 0),
  outstanding_balance   NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (outstanding_balance >= 0),
  payment_status        VARCHAR(30) NOT NULL DEFAULT 'unpaid',
  notes                 TEXT,
  client_transaction_id VARCHAR(100),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS ix_supplier_purchases_company_id ON supplier_purchases (company_id);
CREATE INDEX IF NOT EXISTS ix_supplier_purchases_supplier_id ON supplier_purchases (supplier_id);
CREATE INDEX IF NOT EXISTS ix_supplier_purchases_company_supplier ON supplier_purchases (company_id, supplier_id);
CREATE INDEX IF NOT EXISTS ix_supplier_purchases_date ON supplier_purchases (company_id, purchase_date);
CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_purchases_client_tx ON supplier_purchases (company_id, client_transaction_id) WHERE client_transaction_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_supplier_purchases_updated_at ON supplier_purchases;
CREATE TRIGGER trg_supplier_purchases_updated_at
  BEFORE UPDATE ON supplier_purchases
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS supplier_purchase_items (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id           UUID NOT NULL REFERENCES supplier_purchases(id) ON DELETE CASCADE,
  company_id            UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  product_id            UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name          VARCHAR(255) NOT NULL,
  quantity              NUMERIC(12, 2) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_cost             NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (unit_cost >= 0),
  line_total            NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (line_total >= 0),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_supplier_purchase_items_purchase_id ON supplier_purchase_items (purchase_id);
CREATE INDEX IF NOT EXISTS ix_supplier_purchase_items_company_id ON supplier_purchase_items (company_id);
CREATE INDEX IF NOT EXISTS ix_supplier_purchase_items_product_id ON supplier_purchase_items (product_id);

CREATE TABLE IF NOT EXISTS supplier_payments (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  supplier_id           UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  purchase_id           UUID REFERENCES supplier_purchases(id) ON DELETE SET NULL,
  amount                NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
  payment_date          TIMESTAMPTZ NOT NULL DEFAULT now(),
  payment_method        VARCHAR(50) NOT NULL DEFAULT 'cash',
  reference             VARCHAR(100),
  notes                 TEXT,
  client_id             VARCHAR(100),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS ix_supplier_payments_company_id ON supplier_payments (company_id);
CREATE INDEX IF NOT EXISTS ix_supplier_payments_supplier_id ON supplier_payments (supplier_id);
CREATE INDEX IF NOT EXISTS ix_supplier_payments_purchase_id ON supplier_payments (purchase_id);
CREATE INDEX IF NOT EXISTS ix_supplier_payments_date ON supplier_payments (company_id, payment_date);
CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_payments_client_id ON supplier_payments (company_id, client_id) WHERE client_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_supplier_payments_updated_at ON supplier_payments;
CREATE TRIGGER trg_supplier_payments_updated_at
  BEFORE UPDATE ON supplier_payments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 006_create_products.sql
-- Inventory catalog (Ch. 10). expiration_date is nullable — required only
-- for grocery/pharmacy profiles at the application-validation layer, not
-- enforced here at the DB level (business types vary too much for a DB CHECK).

CREATE TABLE products (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id       UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  supplier_id      UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  name             VARCHAR(150) NOT NULL,
  category         VARCHAR(80),
  barcode          VARCHAR(64),
  purchase_price   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (purchase_price >= 0),
  selling_price    NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
  quantity         INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  minimum_stock    INTEGER NOT NULL DEFAULT 5 CHECK (minimum_stock >= 0),
  expiration_date  DATE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at       TIMESTAMPTZ
);

CREATE INDEX ix_products_company_id ON products (company_id);
CREATE INDEX ix_products_company_barcode ON products (company_id, barcode);
CREATE INDEX ix_products_low_stock ON products (company_id, quantity, minimum_stock);

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 007_create_sales.sql
-- Sales transactions + line items (Ch. 11, 12).
-- unit_cost is SNAPSHOTTED on sale_items at time of sale so historical
-- profit figures never change if a product's purchase_price is edited later.

CREATE TYPE payment_status_enum AS ENUM ('paid', 'unpaid', 'partial');

CREATE TABLE sales (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id       UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id      UUID REFERENCES customers(id) ON DELETE SET NULL,
  employee_id      UUID REFERENCES employees(id) ON DELETE SET NULL,
  subtotal         NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount         NUMERIC(12,2) NOT NULL DEFAULT 0,
  total            NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_status   payment_status_enum NOT NULL DEFAULT 'paid',
  sold_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_sales_company_id ON sales (company_id);
CREATE INDEX ix_sales_company_sold_at ON sales (company_id, sold_at);

CREATE TRIGGER trg_sales_updated_at
  BEFORE UPDATE ON sales
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE sale_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id        UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id     UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity       INTEGER NOT NULL CHECK (quantity > 0),
  unit_price     NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0), -- snapshot of selling_price
  unit_cost      NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),  -- snapshot of purchase_price
  line_total     NUMERIC(12,2) NOT NULL,                          -- unit_price * quantity
  line_profit    NUMERIC(12,2) NOT NULL                           -- (unit_price - unit_cost) * quantity
);

CREATE INDEX ix_sale_items_sale_id ON sale_items (sale_id);
CREATE INDEX ix_sale_items_product_id ON sale_items (product_id);

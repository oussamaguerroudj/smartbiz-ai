-- 032_add_order_id_to_invoices.sql
-- Allow invoices to reference either sales (retail/supermarket) or restaurant_orders (restaurant).

ALTER TABLE invoices ALTER COLUMN sale_id DROP NOT NULL;

ALTER TABLE invoices ADD COLUMN IF NOT EXISTS order_id UUID UNIQUE REFERENCES restaurant_orders(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_invoices_order_id ON invoices (company_id, order_id);

DO $$
BEGIN
  ALTER TABLE invoices DROP CONSTRAINT IF EXISTS chk_invoices_source;
  ALTER TABLE invoices ADD CONSTRAINT chk_invoices_source
    CHECK (
      (sale_id IS NOT NULL AND order_id IS NULL)
      OR
      (sale_id IS NULL AND order_id IS NOT NULL)
    );
END $$;

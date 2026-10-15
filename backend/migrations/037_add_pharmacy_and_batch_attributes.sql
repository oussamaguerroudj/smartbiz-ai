-- 037_add_pharmacy_and_batch_attributes.sql
-- Additive nullable columns for Pharmacy metadata and batch tracking.
-- All columns are nullable; existing catalog data is 100% preserved.

ALTER TABLE products ADD COLUMN IF NOT EXISTS dosage VARCHAR(80);
ALTER TABLE products ADD COLUMN IF NOT EXISTS form VARCHAR(80);
ALTER TABLE products ADD COLUMN IF NOT EXISTS active_ingredient VARCHAR(150);
ALTER TABLE products ADD COLUMN IF NOT EXISTS batch_number VARCHAR(80);

CREATE INDEX IF NOT EXISTS ix_products_batch_number ON products (company_id, batch_number);
CREATE INDEX IF NOT EXISTS ix_products_expiration ON products (company_id, expiration_date);

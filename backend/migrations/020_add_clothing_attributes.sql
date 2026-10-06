-- 020_add_clothing_attributes.sql
-- Business-specialization brief Ch. 18 (Clothing Store) asks for
-- Size / Color / Brand as visible product attributes. Per Ch. 21's
-- "do not fake data" rule, these did not exist anywhere in the schema
-- (only `category` does) — so, exactly like migration 006's
-- `expiration_date` was reserved ahead of Pharmacy needing it, this
-- migration adds three plain nullable columns to the existing CORE
-- `products` table rather than creating a new `clothing_*` table.
--
-- Purely additive, zero risk to existing rows: every other business
-- type simply never sets these columns and they stay NULL forever —
-- same "safe default" property every other ALTER TABLE ... ADD COLUMN
-- in this codebase has (e.g. 013_add_expense_periods.sql,
-- 018_add_clinic_consultation_payments.sql).

ALTER TABLE products ADD COLUMN size  VARCHAR(30);
ALTER TABLE products ADD COLUMN color VARCHAR(40);
ALTER TABLE products ADD COLUMN brand VARCHAR(80);

-- Not indexed: these are display/filter attributes on an already-small
-- per-company table (products.company_id is already indexed), not a
-- high-cardinality lookup key the way barcode is.

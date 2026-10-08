-- 016_expand_business_types.sql
-- Ch. 1/29/30  -  SPECIALIZED BUSINESS CONTENT.
--
-- Purely additive: ALTER TYPE ... ADD VALUE never removes or renames an
-- existing enum label, so every company row that already has
-- business_type = 'clothing' / 'grocery' / 'pharmacy' / 'clinic' /
-- 'restaurant' / 'company' / 'workshop' keeps working exactly as
-- before (Ch. 30 backward compatibility). This migration only adds the
-- remaining types from the requested list of 21.
--
-- NOTE: in PostgreSQL, a newly-added enum value cannot be used in the
-- SAME transaction it was added in. If your migration runner wraps
-- every file in one implicit transaction, run the ADD VALUE statements
-- below first, commit, THEN run 017_create_clinic_tables.sql (which
-- doesn't touch this enum, so this isn't actually a problem for this
-- pair of migrations)  -  flagged here regardless for future specialized
-- migrations that might insert a row using a type added in this same
-- file.

ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'retail_store';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'cafe';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'beauty_salon';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'barbershop';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'gym';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'hotel';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'dental_clinic';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'medical_laboratory';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'car_repair';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'electronics_store';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'supermarket';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'bakery';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'law_office';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'accounting_office';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'real_estate_agency';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'education_center';
ALTER TYPE business_type_enum ADD VALUE IF NOT EXISTS 'other';

-- Every value this project currently knows how to build a Specialized
-- Module for (Ch. 2's CORE + SPECIALIZED split). A business_type NOT in
-- this list still works fully at the CORE level (Sales/Invoices/
-- Expenses/etc.)  -  it just has no extra specialized screens yet, which
-- is the correct, safe default for a type someone picks before its
-- module is built (e.g. 'gym', 'hotel' as of this migration).
--
-- This table is intentionally tiny and just documents the mapping; the
-- actual per-vertical tables (clinic_*, restaurant_*, ...) are added
-- one migration per vertical as each is implemented, never all at once,
-- so a half-built vertical never leaves a company account half-broken.
COMMENT ON TYPE business_type_enum IS
  'Ch. 1/29: core CRM works for every value; SPECIALIZED modules (clinic_*, restaurant_* tables, dedicated Flutter screens) exist only for the subset actually implemented so far  -  see backend/SPECIALIZED_MODULES.md.';

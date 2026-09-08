-- 001_create_companies.sql
-- The tenant-root table. Every other operational table references this
-- via company_id (see Phase 1, Ch. 24 — Design Rationale).

CREATE TYPE business_type_enum AS ENUM (
  'clothing', 'grocery', 'pharmacy', 'clinic', 'restaurant', 'company', 'workshop'
);

CREATE TABLE companies (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           VARCHAR(120) NOT NULL,
  business_type  business_type_enum NOT NULL,
  currency       VARCHAR(10) NOT NULL DEFAULT 'DZD',
  phone          VARCHAR(30),
  address        VARCHAR(255),
  logo_url       TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_companies_updated_at
  BEFORE UPDATE ON companies
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

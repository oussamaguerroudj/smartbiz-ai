-- 019_add_industry_type_to_pending.sql
-- Adds industry and type columns to pending_registrations to persist user selections
-- during registration until verification completes.

ALTER TABLE pending_registrations
  ADD COLUMN IF NOT EXISTS industry TEXT,
  ADD COLUMN IF NOT EXISTS type TEXT;

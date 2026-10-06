-- 013_add_expense_periods.sql
-- Fixes the "one payment covering several months gets counted entirely
-- on the day it was entered" bug: an expense now explicitly states the
-- real span of time it covers (period_start..period_end), and every
-- profit/report/dashboard query below prorates it across that span by
-- day, instead of dumping the whole amount onto expense_date.
--
-- Example from the spec: Electricity, 500,000 DA, covering
-- 2026-07-01..2026-09-30 (3 months) now contributes ~5,555 DA/day
-- (500000 / 92 days) to whichever day/month/year/custom range you ask
-- about, rather than 500,000 DA appearing entirely on one single day.

CREATE TYPE expense_period_type_enum AS ENUM ('one_time', 'daily', 'monthly', 'yearly', 'custom');

ALTER TABLE expenses
  ADD COLUMN period_type  expense_period_type_enum NOT NULL DEFAULT 'one_time',
  ADD COLUMN period_start DATE,
  ADD COLUMN period_end   DATE;

-- Backfill: every expense recorded before this migration behaves
-- exactly as it did before (a one-day, one_time cost on its own
-- expense_date) unless/until the user edits it to state a real period.
UPDATE expenses
SET period_start = expense_date,
    period_end = expense_date
WHERE period_start IS NULL;

ALTER TABLE expenses
  ALTER COLUMN period_start SET NOT NULL,
  ALTER COLUMN period_end SET NOT NULL,
  ADD CONSTRAINT chk_expense_period_valid CHECK (period_end >= period_start);

CREATE INDEX ix_expenses_period ON expenses (company_id, period_start, period_end);

-- Reusable day-overlap proration: how much of `p_amount` (which is
-- spread evenly across p_period_start..p_period_end) falls inside
-- p_range_start..p_range_end. Returns 0 if the period and the range
-- don't overlap at all. IMMUTABLE so Postgres can use it freely in
-- indexed/aggregate queries.
CREATE OR REPLACE FUNCTION expense_prorated_amount(
  p_amount NUMERIC,
  p_period_start DATE,
  p_period_end DATE,
  p_range_start DATE,
  p_range_end DATE
) RETURNS NUMERIC AS $$
DECLARE
  total_days INT;
  overlap_days INT;
BEGIN
  total_days := (p_period_end - p_period_start) + 1;

  IF total_days <= 0 THEN
    RETURN 0;
  END IF;

  overlap_days := LEAST(p_period_end, p_range_end) - GREATEST(p_period_start, p_range_start) + 1;

  IF overlap_days <= 0 THEN
    RETURN 0;
  END IF;

  RETURN p_amount * (overlap_days::NUMERIC / total_days::NUMERIC);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

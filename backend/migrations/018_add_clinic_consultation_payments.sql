-- 018_add_clinic_consultation_payments.sql
-- Clinic Consultation Payments (spec §7-11  -  "VERY IMPORTANT"):
-- clinic revenue must come from actual patient consultation payments,
-- never from product-sale logic. This was the one piece of the Clinic
-- vertical that 017_create_clinic_tables.sql did not build yet  -  this
-- migration adds it without touching any existing clinic/core table.
--
-- Design:
--   * clinic_visits gets a price/paid snapshot (consultation_price,
--     amount_paid, payment_status) so a single visit row always shows
--     its own current payment state without a JOIN.
--   * clinic_payments is the append-only ledger of every payment (and
--     refund, as a negative amount) ever recorded against a visit  - 
--     this is what "Today's / This week's / This month's consultation
--     revenue" actually sums, keyed by paid_at (the day money changed
--     hands), not visited_at (the day the consultation happened). A
--     payment made today toward last week's visit counts as today's
--     revenue, matching how cash actually moves.
--   * amount_paid on clinic_visits is a denormalized running total of
--     its own clinic_payments rows, kept in sync by the service layer
--     inside the same transaction as every insert  -  read-heavy screens
--     (patient profile, queue) never need to re-sum the ledger.

CREATE TYPE clinic_payment_status_enum AS ENUM (
  'unpaid', 'partially_paid', 'paid', 'refunded'
);

ALTER TABLE clinic_visits
  ADD COLUMN consultation_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN amount_paid        NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN payment_status     clinic_payment_status_enum NOT NULL DEFAULT 'unpaid';

CREATE TABLE clinic_payments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  visit_id     UUID NOT NULL REFERENCES clinic_visits(id) ON DELETE CASCADE,
  patient_id   UUID NOT NULL REFERENCES clinic_patients(id) ON DELETE CASCADE,
  -- Negative amount = a refund against this visit (Ch. 8's "Refunded"
  -- status), recorded as a real ledger line rather than mutating or
  -- deleting a prior payment row, so the ledger always reconciles.
  amount       NUMERIC(12,2) NOT NULL,
  method       VARCHAR(40),
  note         VARCHAR(255),
  paid_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- company_id is denormalized onto every payment row (never derived only
-- via a JOIN to clinic_visits/clinic_patients)  -  same tenant-isolation
-- rule every other clinic/CORE table already follows (Ch. 24).
CREATE INDEX ix_clinic_payments_company_paidat ON clinic_payments (company_id, paid_at);
CREATE INDEX ix_clinic_payments_visit ON clinic_payments (visit_id);
CREATE INDEX ix_clinic_payments_patient ON clinic_payments (patient_id);

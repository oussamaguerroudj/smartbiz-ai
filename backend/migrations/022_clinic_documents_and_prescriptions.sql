-- 022_clinic_documents_and_prescriptions.sql
-- Clinic module audit (Chunks 4/5/6/7 of the Clinic spec) — two gaps
-- found in 017_create_clinic_tables.sql that this migration closes
-- without touching any existing clinic/core table or column:
--
--   1. clinic_documents had no uploader, file size, file type, or
--      description, and no soft-delete column, so "who uploaded this",
--      "how big is it", and "delete a document" (spec Ch. 4) had
--      nowhere to be recorded. Added as new nullable/defaulted columns
--      — existing rows remain valid with no backfill required.
--
--   2. There was no prescription entity at all — `clinic_visits.prescription`
--      is a single free-text column, so "multiple medications per
--      prescription" (spec Ch. 6) and "unique identifier" / "view it
--      later" (Ch. 6) had no structure to live in. clinic_visits.prescription
--      is left exactly as-is (still used for the quick free-text note a
--      doctor types while finishing a consultation) — clinic_prescriptions
--      is an additive, optional, more structured record a doctor can
--      create for a patient when they need one, same relationship
--      appointments already have to visits (planned vs. what happened).

ALTER TABLE clinic_documents
  ADD COLUMN uploaded_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN file_size    BIGINT,
  ADD COLUMN file_type    VARCHAR(100),
  ADD COLUMN description  VARCHAR(500),
  ADD COLUMN deleted_at   TIMESTAMPTZ;

-- Existing `findDocumentsByPatient` queries are updated (application
-- code, this migration) to filter deleted_at IS NULL, matching the
-- exact soft-delete pattern clinic_patients already uses.

CREATE TABLE clinic_prescriptions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id           UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  patient_id           UUID NOT NULL REFERENCES clinic_patients(id) ON DELETE CASCADE,
  doctor_id            UUID REFERENCES employees(id) ON DELETE SET NULL,
  visit_id             UUID REFERENCES clinic_visits(id) ON DELETE SET NULL,
  prescription_number  VARCHAR(30) NOT NULL,
  notes                TEXT,
  issued_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by           UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Same per-company sequential numbering pattern as invoices
-- (sales.repository.nextInvoiceNumber: "INV-<n>", FOR UPDATE-locked
-- company row) — reused here as "RX-<n>", not a new numbering scheme.
CREATE UNIQUE INDEX ux_clinic_prescriptions_company_number
  ON clinic_prescriptions (company_id, prescription_number);
CREATE INDEX ix_clinic_prescriptions_patient ON clinic_prescriptions (patient_id, issued_at);
CREATE INDEX ix_clinic_prescriptions_company ON clinic_prescriptions (company_id);

-- One row per medication line (spec Ch. 6: "Allow multiple
-- medications/items in the same prescription"). quantity/dosage/
-- frequency/duration are free text (VARCHAR), matching this codebase's
-- existing convention for values a doctor types rather than picks from
-- a fixed unit list (e.g. clinic_appointments.appointment_type).
CREATE TABLE clinic_prescription_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id   UUID NOT NULL REFERENCES clinic_prescriptions(id) ON DELETE CASCADE,
  medication_name   VARCHAR(200) NOT NULL,
  dosage            VARCHAR(100),
  quantity          VARCHAR(50),
  frequency         VARCHAR(100),
  duration          VARCHAR(100),
  instructions      TEXT,
  sort_order        INT NOT NULL DEFAULT 0
);

CREATE INDEX ix_clinic_prescription_items_prescription
  ON clinic_prescription_items (prescription_id, sort_order);

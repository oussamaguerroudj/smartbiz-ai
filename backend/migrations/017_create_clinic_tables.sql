-- 017_create_clinic_tables.sql
-- Ch. 3 — CLINIC SPECIAL CONTENT. First fully-implemented specialized
-- vertical; every other vertical (restaurant, gym, hotel, ...) follows
-- this exact same pattern — see backend/SPECIALIZED_MODULES.md.
--
-- SECURITY (Ch. 24 — data isolation): every table below carries its own
-- company_id, not just a join through patient_id/appointment_id, so
-- every query can filter directly on `WHERE company_id = $1` the same
-- way every existing CORE table already does — no new isolation
-- mechanism to reason about, no risk of a missing JOIN silently
-- widening visibility across tenants.
--
-- Doctors are NOT a new table: `employees.position` (already free-text,
-- see 003_create_employees.sql) is reused — a clinic's doctors are just
-- employees whose position happens to say "Doctor". This avoids a
-- redundant doctors table (Ch. 31: reuse existing components).

CREATE TABLE clinic_patients (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  full_name         VARCHAR(150) NOT NULL,
  date_of_birth     DATE,
  gender            VARCHAR(20),
  phone             VARCHAR(30),
  email             VARCHAR(150),
  address           VARCHAR(255),
  emergency_contact VARCHAR(150),
  assigned_doctor_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

CREATE INDEX ix_clinic_patients_company ON clinic_patients (company_id);

CREATE TRIGGER trg_clinic_patients_updated_at
  BEFORE UPDATE ON clinic_patients
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TYPE clinic_appointment_status_enum AS ENUM (
  'scheduled', 'confirmed', 'waiting', 'in_consultation', 'completed', 'cancelled', 'no_show'
);

CREATE TABLE clinic_appointments (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  patient_id     UUID NOT NULL REFERENCES clinic_patients(id) ON DELETE CASCADE,
  doctor_id      UUID REFERENCES employees(id) ON DELETE SET NULL,
  scheduled_at   TIMESTAMPTZ NOT NULL,
  appointment_type VARCHAR(80),
  status         clinic_appointment_status_enum NOT NULL DEFAULT 'scheduled',
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_clinic_appointments_company ON clinic_appointments (company_id);
CREATE INDEX ix_clinic_appointments_patient ON clinic_appointments (patient_id);
CREATE INDEX ix_clinic_appointments_scheduled ON clinic_appointments (company_id, scheduled_at);

CREATE TRIGGER trg_clinic_appointments_updated_at
  BEFORE UPDATE ON clinic_appointments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Waiting Room / Queue (Ch. 3.F — "من أهم الخصائص"). Deliberately
-- separate from clinic_appointments: an appointment is a planned slot:
-- a queue entry is "this specific patient is physically here right
-- now", created either from a scheduled appointment or as a walk-in
-- (appointment_id nullable). `position` is the visible queue number
-- ("#01", "#02"...), assigned sequentially per company per day.
CREATE TYPE clinic_queue_status_enum AS ENUM (
  'waiting', 'next', 'in_consultation', 'completed', 'cancelled'
);

CREATE TABLE clinic_queue (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  patient_id     UUID NOT NULL REFERENCES clinic_patients(id) ON DELETE CASCADE,
  appointment_id UUID REFERENCES clinic_appointments(id) ON DELETE SET NULL,
  doctor_id      UUID REFERENCES employees(id) ON DELETE SET NULL,
  position       INT NOT NULL,
  visit_type     VARCHAR(80),
  status         clinic_queue_status_enum NOT NULL DEFAULT 'waiting',
  arrived_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  called_at      TIMESTAMPTZ,
  completed_at   TIMESTAMPTZ
);

CREATE INDEX ix_clinic_queue_company_status ON clinic_queue (company_id, status, position);

-- One row per real consultation (Ch. 3.H). A queue entry becomes a
-- visit the moment a doctor starts consulting — see clinic.service.js.
CREATE TABLE clinic_visits (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  patient_id      UUID NOT NULL REFERENCES clinic_patients(id) ON DELETE CASCADE,
  doctor_id       UUID REFERENCES employees(id) ON DELETE SET NULL,
  appointment_id  UUID REFERENCES clinic_appointments(id) ON DELETE SET NULL,
  reason          VARCHAR(255),
  symptoms        TEXT,
  diagnosis       TEXT,
  treatment       TEXT,
  prescription    TEXT,
  notes           TEXT,
  follow_up_date  DATE,
  visited_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_clinic_visits_company ON clinic_visits (company_id);
CREATE INDEX ix_clinic_visits_patient ON clinic_visits (patient_id, visited_at);

-- Patient documents (Ch. 3.D) — stores a URL/reference only (this
-- project has no file-upload storage service wired up yet; documented
-- as a follow-up in SPECIALIZED_MODULES.md rather than built ad hoc
-- here).
CREATE TABLE clinic_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  patient_id   UUID NOT NULL REFERENCES clinic_patients(id) ON DELETE CASCADE,
  visit_id     UUID REFERENCES clinic_visits(id) ON DELETE SET NULL,
  file_name    VARCHAR(255) NOT NULL,
  file_url     TEXT NOT NULL,
  document_type VARCHAR(80),
  uploaded_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_clinic_documents_patient ON clinic_documents (patient_id);

-- 010_create_appointments.sql
-- Scheduled appointments, primarily for clinics but available to any type (Ch. 18).

CREATE TYPE appointment_status_enum AS ENUM ('scheduled', 'completed', 'cancelled', 'no_show');

CREATE TABLE appointments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id       UUID REFERENCES customers(id) ON DELETE SET NULL,
  title             VARCHAR(150),
  notes             VARCHAR(500),
  scheduled_at      TIMESTAMPTZ NOT NULL,
  status            appointment_status_enum NOT NULL DEFAULT 'scheduled',
  reminder_enabled  BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_appointments_company_id ON appointments (company_id);
CREATE INDEX ix_appointments_company_scheduled ON appointments (company_id, scheduled_at);

CREATE TRIGGER trg_appointments_updated_at
  BEFORE UPDATE ON appointments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

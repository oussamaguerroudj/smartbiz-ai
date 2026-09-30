-- 003_create_employees.sql
-- Staff records (Ch. 17): profile, attendance, and salary adjustments.

CREATE TABLE employees (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name           VARCHAR(120) NOT NULL,
  position       VARCHAR(80),
  phone          VARCHAR(30),
  base_salary    NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (base_salary >= 0),
  joined_at      DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ
);

CREATE INDEX ix_employees_company_id ON employees (company_id);

CREATE TRIGGER trg_employees_updated_at
  BEFORE UPDATE ON employees
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Daily attendance (Ch. 17.2)
CREATE TYPE attendance_status_enum AS ENUM ('present', 'absent', 'late');

CREATE TABLE attendance_records (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  employee_id    UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  work_date      DATE NOT NULL,
  status         attendance_status_enum NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (employee_id, work_date)
);

CREATE INDEX ix_attendance_company_id ON attendance_records (company_id);
CREATE INDEX ix_attendance_employee_id ON attendance_records (employee_id);

-- Salary adjustments: bonuses/deductions applied on top of base_salary (Ch. 17.3)
CREATE TYPE salary_adjustment_type_enum AS ENUM ('bonus', 'deduction');

CREATE TABLE salary_adjustments (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  employee_id    UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  type           salary_adjustment_type_enum NOT NULL,
  amount         NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  period_month   DATE NOT NULL, -- first day of the payroll month, e.g. 2026-09-01
  note           VARCHAR(255),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_salary_adjustments_employee_period
  ON salary_adjustments (employee_id, period_month);

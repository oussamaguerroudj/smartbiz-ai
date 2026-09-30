-- 021_create_enterprise_projects.sql
-- Enterprise / Company vertical (business-specialization brief Ch. 19).
--
-- The ONLY new table this vertical needs. Clients (`customers`),
-- Employees/Salaries (`employees`, `salary_adjustments`), Suppliers,
-- Invoices, Payments (`invoices`, `sales`, `credit_payments`) and
-- Expenses already exist as CORE tables and are reused as-is (Ch. 21);
-- "Projects" is the one concept from Ch. 19 with no home anywhere in
-- the schema, so it gets its own `enterprise_*` table.
--
-- Same tenant-isolation rule as every other specialized table:
-- `company_id` on the row itself, never derived only via a JOIN.
-- `customer_id` optionally links a project to the client it is for.

CREATE TYPE enterprise_project_status_enum AS ENUM (
  'planned',
  'active',
  'on_hold',
  'completed',
  'cancelled'
);

CREATE TABLE enterprise_projects (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id    UUID REFERENCES customers(id) ON DELETE SET NULL,
  name           VARCHAR(150) NOT NULL,
  description    TEXT,
  status         enterprise_project_status_enum NOT NULL DEFAULT 'planned',
  budget         NUMERIC(12,2) CHECK (budget IS NULL OR budget >= 0),
  start_date     DATE,
  due_date       DATE,
  completed_at   TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ,
  CHECK (start_date IS NULL OR due_date IS NULL OR due_date >= start_date)
);

CREATE INDEX ix_enterprise_projects_company ON enterprise_projects (company_id);
CREATE INDEX ix_enterprise_projects_company_status ON enterprise_projects (company_id, status);

CREATE TRIGGER trg_enterprise_projects_updated_at
  BEFORE UPDATE ON enterprise_projects
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

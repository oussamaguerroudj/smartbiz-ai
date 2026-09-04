-- 002_create_users.sql
-- Application accounts. role drives Authorization (Phase 1, Ch. 9).

CREATE TYPE user_role_enum AS ENUM ('owner', 'staff');

CREATE TABLE users (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name           VARCHAR(120) NOT NULL,
  email          VARCHAR(180) NOT NULL,
  password_hash  TEXT NOT NULL,
  role           user_role_enum NOT NULL DEFAULT 'staff',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ
);

-- Email must be unique globally (used as login identifier).
CREATE UNIQUE INDEX ux_users_email ON users (email) WHERE deleted_at IS NULL;
CREATE INDEX ix_users_company_id ON users (company_id);

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

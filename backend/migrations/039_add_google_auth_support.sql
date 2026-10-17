-- 039_add_google_auth_support.sql
-- Additive migration for Google OAuth integration:
-- 1. Allow password_hash to be NULL for accounts created via Google OAuth.
-- 2. Add google_id and auth_provider columns to users table.
-- 3. Create unique index on google_id scoped to active (non-deleted) users.

ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(50) NOT NULL DEFAULT 'local';

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_google_id ON users (google_id) WHERE deleted_at IS NULL;

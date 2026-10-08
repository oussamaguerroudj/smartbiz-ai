-- Migration: email verification + password reset
--
-- No existing migrations folder shipped in this zip (companies.routes.js
-- references "Phase 3 migration 001" and database/README.md, but neither
-- was included here) — this is written as a new, additive migration
-- against the existing `users` table schema implied by auth.service.js
-- (id, company_id, name, email, password_hash, role, deleted_at).
-- Run this by hand against your real database; nothing in this batch
-- runs it automatically since this sandbox has no DB connection.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_code_hash TEXT,
  ADD COLUMN IF NOT EXISTS verification_code_expires TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verification_attempts INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS password_resets (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_resets_user_id ON password_resets(user_id);


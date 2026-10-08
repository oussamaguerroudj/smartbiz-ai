-- Migration: pending (not-yet-verified) registrations
--
-- Pairs with 002_email_verification_and_password_reset.sql. That
-- migration added email_verified / verification_code_* columns onto
-- `users` directly, which meant a `users` row (and therefore the
-- account itself) was created at registration time, before the email
-- was ever confirmed. That's what caused "an account with this email
-- already exists" for someone who registered but never entered their
-- code  -  the row was already sitting there.
--
-- This migration moves the not-yet-verified state out of `users`
-- entirely. A signup now only creates a row here; the corresponding
-- `users` (+ `companies`) row is created for the first time inside
-- auth.service.js#verifyEmail, only once the correct code is confirmed.
-- Until then, as far as `users` is concerned, the account simply does
-- not exist  -  so a second registration attempt with the same email is
-- just treated as "try again" (this row gets overwritten with a fresh
-- code) instead of a conflict.
--
-- Run this by hand against your real database, after 002_*; nothing in
-- this batch runs it automatically since this sandbox has no DB
-- connection.

CREATE TABLE IF NOT EXISTS pending_registrations (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  code_expires TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pending_registrations_email
  ON pending_registrations (email);

-- Optional cleanup helper  -  safe to run periodically (e.g. a cron job)
-- to drop long-abandoned signups. Not required for correctness: an
-- abandoned row is harmless and gets overwritten the moment that email
-- registers again, but this keeps the table from growing forever with
-- signups nobody ever came back to confirm.
-- DELETE FROM pending_registrations WHERE updated_at < now() - interval '7 days';

-- The verification_code_hash / verification_code_expires /
-- verification_attempts columns added to `users` by 002_* are no longer
-- written to or read by the app (every `users` row is created already
-- verified now). Left in place rather than dropped here, since dropping
-- columns is harder to undo than simply ignoring them  -  uncomment if you
-- want them gone:
-- ALTER TABLE users
--   DROP COLUMN IF EXISTS verification_code_hash,
--   DROP COLUMN IF EXISTS verification_code_expires,
--   DROP COLUMN IF EXISTS verification_attempts;

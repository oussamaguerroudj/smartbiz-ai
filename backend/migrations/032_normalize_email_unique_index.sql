-- 032_normalize_email_unique_index.sql
-- Enforce unique index on normalized lower(trim(email)) in users and pending_registrations.
-- Fails loudly if existing duplicates exist (never merges or deletes).

DO $$
DECLARE
  dup_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO dup_count
  FROM (
    SELECT lower(trim(email))
    FROM users
    WHERE deleted_at IS NULL
    GROUP BY lower(trim(email))
    HAVING COUNT(*) > 1
  ) dups;

  IF dup_count > 0 THEN
    RAISE EXCEPTION 'FATAL: Cannot apply migration 032 — % duplicate normalized email group(s) exist in users table. Resolve manually before migrating.', dup_count;
  END IF;

  SELECT COUNT(*) INTO dup_count
  FROM (
    SELECT lower(trim(email))
    FROM pending_registrations
    GROUP BY lower(trim(email))
    HAVING COUNT(*) > 1
  ) dups_pending;

  IF dup_count > 0 THEN
    RAISE EXCEPTION 'FATAL: Cannot apply migration 032 — % duplicate normalized email group(s) exist in pending_registrations table. Resolve manually before migrating.', dup_count;
  END IF;
END $$;

DROP INDEX IF EXISTS ux_users_email;
CREATE UNIQUE INDEX ux_users_email ON users (lower(trim(email))) WHERE deleted_at IS NULL;

ALTER TABLE pending_registrations DROP CONSTRAINT IF EXISTS pending_registrations_email_key;
DROP INDEX IF EXISTS idx_pending_registrations_email;
CREATE UNIQUE INDEX idx_pending_registrations_email ON pending_registrations (lower(trim(email)));


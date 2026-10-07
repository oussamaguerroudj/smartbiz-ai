-- Migration 031: Extend user_role_enum to safely support 'super_admin' and 'support' roles.
-- Non-destructive: preserves existing 'owner' and 'staff' roles and records.
ALTER TYPE user_role_enum ADD VALUE IF NOT EXISTS 'super_admin';
ALTER TYPE user_role_enum ADD VALUE IF NOT EXISTS 'support';

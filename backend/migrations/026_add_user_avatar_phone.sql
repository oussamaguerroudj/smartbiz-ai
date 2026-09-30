-- 026_add_user_avatar_phone.sql
-- Add optional avatar_url and phone columns to users table for profile management.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS phone VARCHAR(50);

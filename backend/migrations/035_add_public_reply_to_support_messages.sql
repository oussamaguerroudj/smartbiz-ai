-- 035_add_public_reply_to_support_messages.sql
-- Adds dedicated user-facing administrator reply column to support_messages.
-- Internal administrator notes (admin_notes) remain strictly confidential to Super Admins.

ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS public_reply TEXT;

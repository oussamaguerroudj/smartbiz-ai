-- 033_nullable_business_type_and_onboarding.sql
-- Allow business_type to be NULL for companies during onboarding.
-- Add onboarding_completed BOOLEAN NOT NULL DEFAULT true so existing rows remain marked completed.

ALTER TABLE companies ALTER COLUMN business_type DROP NOT NULL;

ALTER TABLE companies ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT true;

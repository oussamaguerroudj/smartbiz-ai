-- 034_flag_placeholder_companies.sql
-- Flags legacy placeholder companies (name = 'New Business' AND business_type = 'company')
-- as incomplete onboarding (onboarding_completed = false, business_type = NULL).
--
-- CAUTION / DEPLOY NOTE:
-- Review matching rows before applying to any database with real users:
-- SELECT id, name, business_type, created_at FROM companies WHERE name = 'New Business' AND business_type = 'company';

UPDATE companies
SET onboarding_completed = false,
    business_type = NULL
WHERE name = 'New Business'
  AND business_type = 'company';

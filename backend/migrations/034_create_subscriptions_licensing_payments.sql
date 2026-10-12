-- 1. Extend user_role_enum and notification_type_enum for trial and licensing
ALTER TYPE user_role_enum ADD VALUE IF NOT EXISTS 'super_admin';
ALTER TYPE user_role_enum ADD VALUE IF NOT EXISTS 'support';

ALTER TYPE notification_type_enum ADD VALUE IF NOT EXISTS 'trial_reminder_48h';
ALTER TYPE notification_type_enum ADD VALUE IF NOT EXISTS 'trial_reminder_24h';
ALTER TYPE notification_type_enum ADD VALUE IF NOT EXISTS 'trial_expired';
ALTER TYPE notification_type_enum ADD VALUE IF NOT EXISTS 'license_granted';
ALTER TYPE notification_type_enum ADD VALUE IF NOT EXISTS 'payment_update';

-- 2. Add licensing and account approval columns to companies (tenant-root)
ALTER TABLE companies ADD COLUMN IF NOT EXISTS entitlement_type VARCHAR(30) NOT NULL DEFAULT 'none';
ALTER TABLE companies ADD COLUMN IF NOT EXISTS trial_starts_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS license_expires_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS entitlement_granted_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS entitlement_granted_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS account_approval_status VARCHAR(30) NOT NULL DEFAULT 'approved';
ALTER TABLE companies ADD COLUMN IF NOT EXISTS approval_reviewed_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS approval_reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS suspension_reason TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS trial_reminder_48h_sent_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS trial_reminder_24h_sent_at TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS trial_reminder_expired_sent_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS ix_companies_entitlement ON companies (entitlement_type);
CREATE INDEX IF NOT EXISTS ix_companies_trial_ends ON companies (trial_ends_at) WHERE entitlement_type = 'trial';
CREATE INDEX IF NOT EXISTS ix_companies_approval ON companies (account_approval_status);

-- 3. Electronic and Manual Payment Orders Table
CREATE TABLE IF NOT EXISTS payment_orders (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number         VARCHAR(64) NOT NULL UNIQUE,
  company_id           UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_type         VARCHAR(50) NOT NULL DEFAULT 'lifetime_license',
  payment_method       VARCHAR(30) NOT NULL, -- 'chargily', 'manual_ccp'
  amount               NUMERIC(15,2) NOT NULL DEFAULT 15000.00,
  currency             VARCHAR(10) NOT NULL DEFAULT 'DZD',
  status               VARCHAR(30) NOT NULL DEFAULT 'created', -- 'created','pending','processing','paid','failed','cancelled','expired','refunded','under_review'
  provider_checkout_id VARCHAR(255) UNIQUE,
  provider_payment_id  VARCHAR(255),
  checkout_url         TEXT,
  idempotency_key      VARCHAR(255) UNIQUE,
  raw_response         JSONB,
  paid_at              TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_payment_orders_company_id ON payment_orders (company_id);
CREATE INDEX IF NOT EXISTS ix_payment_orders_user_id ON payment_orders (user_id);
CREATE INDEX IF NOT EXISTS ix_payment_orders_status ON payment_orders (status);

-- 4. Manual CCP Payment Requests and Receipts
CREATE TABLE IF NOT EXISTS manual_payment_requests (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id                 UUID REFERENCES payment_orders(id) ON DELETE SET NULL,
  company_id               UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id                  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount                   NUMERIC(15,2) NOT NULL DEFAULT 15000.00,
  currency                 VARCHAR(10) NOT NULL DEFAULT 'DZD',
  transfer_reference       VARCHAR(100),
  receipt_storage_path     TEXT,
  receipt_original_filename VARCHAR(255),
  receipt_mime_type        VARCHAR(100),
  receipt_file_size        INTEGER,
  receipt_data             BYTEA,
  receipt_uploaded_at      TIMESTAMPTZ,
  status                   VARCHAR(30) NOT NULL DEFAULT 'pending', -- 'pending','under_review','approved','rejected'
  reviewed_by              UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at              TIMESTAMPTZ,
  rejection_reason         TEXT,
  admin_notes              TEXT,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_manual_payments_company_id ON manual_payment_requests (company_id);
CREATE INDEX IF NOT EXISTS ix_manual_payments_status ON manual_payment_requests (status);

-- 5. Webhook Events Table (idempotency & audit for provider deliveries)
CREATE TABLE IF NOT EXISTS payment_webhook_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider     VARCHAR(50) NOT NULL DEFAULT 'chargily',
  event_id     VARCHAR(255) UNIQUE NOT NULL,
  event_type   VARCHAR(100) NOT NULL,
  payload      JSONB NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status       VARCHAR(30) NOT NULL DEFAULT 'processed'
);

-- 6. Immutable License & Entitlement Audit Logs
CREATE TABLE IF NOT EXISTS license_audit_logs (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id               UUID REFERENCES users(id) ON DELETE SET NULL,
  actor_id              UUID REFERENCES users(id) ON DELETE SET NULL,
  action                VARCHAR(50) NOT NULL,
  previous_entitlement  VARCHAR(30),
  new_entitlement       VARCHAR(30),
  previous_expires_at   TIMESTAMPTZ,
  new_expires_at        TIMESTAMPTZ,
  reason                TEXT,
  metadata              JSONB,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_license_audit_company_id ON license_audit_logs (company_id);
CREATE INDEX IF NOT EXISTS ix_license_audit_created_at ON license_audit_logs (created_at DESC);

-- 7. Public & Authenticated Support Inquiries
CREATE TABLE IF NOT EXISTS support_messages (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number VARCHAR(32) NOT NULL UNIQUE,
  user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
  company_id   UUID REFERENCES companies(id) ON DELETE SET NULL,
  name         VARCHAR(120) NOT NULL,
  email        VARCHAR(180) NOT NULL,
  phone        VARCHAR(30),
  category     VARCHAR(50) NOT NULL,
  subject      VARCHAR(200),
  message      TEXT NOT NULL,
  status       VARCHAR(30) NOT NULL DEFAULT 'new', -- 'new','in_progress','answered','closed'
  admin_notes  TEXT,
  assigned_to  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_support_status ON support_messages (status);
CREATE INDEX IF NOT EXISTS ix_support_email ON support_messages (lower(trim(email)));

-- 8. Customer Feedback Submissions
CREATE TABLE IF NOT EXISTS feedback_submissions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  company_id  UUID REFERENCES companies(id) ON DELETE SET NULL,
  category    VARCHAR(50) NOT NULL, -- 'bug_report','ux_feedback','feature_request','general_feedback'
  message     TEXT NOT NULL,
  rating      INTEGER,
  status      VARCHAR(30) NOT NULL DEFAULT 'new',
  admin_notes TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_feedback_status ON feedback_submissions (status);

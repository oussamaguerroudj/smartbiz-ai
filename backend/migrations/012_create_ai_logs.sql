-- 012_create_ai_logs.sql
-- Audit trail of every AI operation (Invoice Scanner, Assistant, Insights).
-- Used for debugging, cost tracking, and rate limiting (Phase 1, Ch. 11 / 27).

CREATE TYPE ai_log_type_enum AS ENUM ('invoice_scan', 'assistant_chat', 'insight_generation');

CREATE TABLE ai_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id        UUID REFERENCES users(id) ON DELETE SET NULL,
  type           ai_log_type_enum NOT NULL,
  input_ref      TEXT,        -- e.g. uploaded image URL, or the user's question
  result         JSONB,       -- structured AI output (never trusted until user-confirmed)
  confirmed      BOOLEAN NOT NULL DEFAULT false, -- true only after user review/confirm
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_ai_logs_company_id ON ai_logs (company_id);
CREATE INDEX ix_ai_logs_company_type ON ai_logs (company_id, type);

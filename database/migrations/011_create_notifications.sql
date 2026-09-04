-- 011_create_notifications.sql
-- In-app notification log (Ch. 19): low stock, appointment reminder,
-- salary reminder, unpaid invoice, expiration warning.

CREATE TYPE notification_type_enum AS ENUM (
  'low_stock', 'appointment_reminder', 'salary_reminder',
  'unpaid_invoice', 'expiration_warning'
);

CREATE TABLE notifications (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,
  type           notification_type_enum NOT NULL,
  title          VARCHAR(150) NOT NULL,
  body           VARCHAR(500),
  reference_id   UUID, -- id of the related product/invoice/appointment/etc.
  read_at        TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_notifications_company_id ON notifications (company_id);
CREATE INDEX ix_notifications_user_unread
  ON notifications (user_id, read_at) WHERE read_at IS NULL;

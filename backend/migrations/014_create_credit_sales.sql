-- 014_create_credit_sales.sql
-- Credit Sale system (Ch. 5-14/17): a customer buys now and pays part
-- (or none) of the total immediately — the rest becomes debt against
-- their `customers.balance_due`, repayable later via one or more
-- payments. Deliberately kept as its OWN set of tables, separate from
-- `sales`/`sale_items`/`invoices`, per the explicit schema requirement
-- (Ch. 17: "Customers / Credit Purchases / Credit Items / Payments /
-- Transactions ... مع العلاقات المناسبة بينهم — لا تخزن كل شيء في
-- Customer object واحد").

CREATE TYPE credit_purchase_status_enum AS ENUM ('paid', 'partial', 'unpaid');

-- Header: one row per Credit Sale transaction.
CREATE TABLE credit_purchases (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id       UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  subtotal          NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
  amount_paid_now   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid_now >= 0),
  remaining_credit  NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (remaining_credit >= 0),
  status            credit_purchase_status_enum NOT NULL DEFAULT 'unpaid',
  created_by        UUID REFERENCES users(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (amount_paid_now <= subtotal),
  CHECK (remaining_credit = subtotal - amount_paid_now)
);

CREATE INDEX ix_credit_purchases_company ON credit_purchases (company_id);
CREATE INDEX ix_credit_purchases_customer ON credit_purchases (customer_id);

-- Line items — mirrors sale_items in spirit, but its own table per the
-- "Credit Items" schema requirement. product_name is a snapshot (like
-- sale_items keeps unit_price/unit_cost snapshots) so a later product
-- rename/deletion never rewrites history.
CREATE TABLE credit_purchase_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  credit_purchase_id  UUID NOT NULL REFERENCES credit_purchases(id) ON DELETE CASCADE,
  product_id          UUID NOT NULL REFERENCES products(id),
  product_name        VARCHAR(150) NOT NULL,
  quantity            INT NOT NULL CHECK (quantity > 0),
  unit_price          NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  line_total          NUMERIC(12,2) NOT NULL CHECK (line_total >= 0)
);

CREATE INDEX ix_credit_purchase_items_purchase ON credit_purchase_items (credit_purchase_id);

-- Every payment ever received against a customer's credit balance —
-- both the "Amount to Pay Now" collected at purchase time (credit_
-- purchase_id set) and any later standalone repayment (credit_
-- purchase_id null — applied to the customer's overall balance).
CREATE TABLE credit_payments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id         UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  credit_purchase_id  UUID REFERENCES credit_purchases(id) ON DELETE SET NULL,
  amount              NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  note                VARCHAR(255),
  created_by          UUID REFERENCES users(id),
  paid_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_credit_payments_company ON credit_payments (company_id);
CREATE INDEX ix_credit_payments_customer ON credit_payments (customer_id);
CREATE INDEX ix_credit_payments_paid_at ON credit_payments (company_id, paid_at);

-- Unified per-customer ledger ("Transaction History" — Ch. 14/20): every
-- credit purchase and every payment appears here as its own row, so the
-- full operation is always visible line-by-line rather than collapsed
-- into a single net number. `amount` is the SIGNED change to balance_due
-- (positive = new debt, negative = debt reduced); `balance_after` is the
-- running balance right after this row, for a running-total display.
CREATE TYPE customer_transaction_type_enum AS ENUM ('credit_purchase', 'payment');

CREATE TABLE customer_transactions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_id    UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  type           customer_transaction_type_enum NOT NULL,
  reference_id   UUID NOT NULL, -- credit_purchases.id or credit_payments.id
  amount         NUMERIC(12,2) NOT NULL,
  balance_after  NUMERIC(12,2) NOT NULL,
  description    VARCHAR(255),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_customer_transactions_customer
  ON customer_transactions (customer_id, created_at);

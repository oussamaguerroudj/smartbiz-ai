-- 019_create_restaurant_tables.sql
-- Restaurant vertical (business-specialization brief Ch. 17)  -  second
-- fully-implemented specialized vertical after Clinic, following the
-- exact pattern documented in backend/SPECIALIZED_MODULES.md §3.
--
-- SECURITY (Ch. 24  -  data isolation): every table below carries its own
-- company_id, not just a join through table_id/order_id, so every
-- query can filter directly on `WHERE company_id = $1` the same way
-- every existing CORE and clinic_* table already does.
--
-- Waiters/Cashiers are NOT a new table: `employees.position` (already
-- free-text, see 003_create_employees.sql) is reused, exactly like
-- Clinic reused it for "Doctor"  -  no redundant staff table.

CREATE TYPE restaurant_table_status_enum AS ENUM (
  'available', 'occupied', 'reserved', 'cleaning'
);

CREATE TABLE restaurant_tables (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name        VARCHAR(50) NOT NULL,
  seats       INT NOT NULL DEFAULT 2,
  status      restaurant_table_status_enum NOT NULL DEFAULT 'available',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX ix_restaurant_tables_company ON restaurant_tables (company_id);

CREATE TRIGGER trg_restaurant_tables_updated_at
  BEFORE UPDATE ON restaurant_tables
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE restaurant_menu_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name         VARCHAR(150) NOT NULL,
  category     VARCHAR(80),
  price        NUMERIC(12,2) NOT NULL DEFAULT 0,
  is_available BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at   TIMESTAMPTZ
);

CREATE INDEX ix_restaurant_menu_items_company ON restaurant_menu_items (company_id);

CREATE TRIGGER trg_restaurant_menu_items_updated_at
  BEFORE UPDATE ON restaurant_menu_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Orders (Ch. 17.A)  -  mirrors clinic_visits' price/paid/payment_status
-- snapshot columns exactly, so revenue logic can reuse the same
-- pattern proven there: never product-sale/invoice logic, a real
-- append-only payments ledger is the source of truth for revenue.
CREATE TYPE restaurant_order_status_enum AS ENUM (
  'pending', 'preparing', 'ready', 'served', 'completed', 'cancelled'
);

CREATE TYPE restaurant_payment_status_enum AS ENUM (
  'unpaid', 'partially_paid', 'paid', 'refunded'
);

CREATE TABLE restaurant_orders (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  table_id       UUID REFERENCES restaurant_tables(id) ON DELETE SET NULL,
  order_number   INT NOT NULL,
  status         restaurant_order_status_enum NOT NULL DEFAULT 'pending',
  total_amount   NUMERIC(12,2) NOT NULL DEFAULT 0,
  amount_paid    NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_status restaurant_payment_status_enum NOT NULL DEFAULT 'unpaid',
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at   TIMESTAMPTZ
);

CREATE INDEX ix_restaurant_orders_company ON restaurant_orders (company_id);
CREATE INDEX ix_restaurant_orders_company_status ON restaurant_orders (company_id, status);
CREATE INDEX ix_restaurant_orders_table ON restaurant_orders (table_id);

CREATE TRIGGER trg_restaurant_orders_updated_at
  BEFORE UPDATE ON restaurant_orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Order line items  -  name/price are snapshotted at order time (never
-- re-read from restaurant_menu_items later) so a later menu price
-- change never rewrites a past order's total, same principle as
-- sales_items already uses for product sales elsewhere in this app.
CREATE TABLE restaurant_order_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  order_id      UUID NOT NULL REFERENCES restaurant_orders(id) ON DELETE CASCADE,
  menu_item_id  UUID REFERENCES restaurant_menu_items(id) ON DELETE SET NULL,
  item_name     VARCHAR(150) NOT NULL,
  unit_price    NUMERIC(12,2) NOT NULL DEFAULT 0,
  quantity      INT NOT NULL DEFAULT 1,
  subtotal      NUMERIC(12,2) NOT NULL DEFAULT 0
);

CREATE INDEX ix_restaurant_order_items_order ON restaurant_order_items (order_id);
CREATE INDEX ix_restaurant_order_items_menu_item ON restaurant_order_items (company_id, menu_item_id);

-- Reservations (Ch. 17.A)
CREATE TYPE restaurant_reservation_status_enum AS ENUM (
  'pending', 'confirmed', 'seated', 'cancelled', 'no_show'
);

CREATE TABLE restaurant_reservations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  customer_name VARCHAR(150) NOT NULL,
  phone         VARCHAR(30),
  party_size    INT NOT NULL DEFAULT 1,
  table_id      UUID REFERENCES restaurant_tables(id) ON DELETE SET NULL,
  reserved_at   TIMESTAMPTZ NOT NULL,
  status        restaurant_reservation_status_enum NOT NULL DEFAULT 'pending',
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_restaurant_reservations_company ON restaurant_reservations (company_id, reserved_at);

CREATE TRIGGER trg_restaurant_reservations_updated_at
  BEFORE UPDATE ON restaurant_reservations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Order payments ledger  -  same append-only design as clinic_payments
-- (018_add_clinic_consultation_payments.sql): a negative amount is a
-- refund, revenue is always summed from this table by paid_at (the day
-- money actually moved), never from restaurant_orders directly.
CREATE TABLE restaurant_payments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  order_id   UUID NOT NULL REFERENCES restaurant_orders(id) ON DELETE CASCADE,
  amount     NUMERIC(12,2) NOT NULL,
  method     VARCHAR(40),
  note       TEXT,
  paid_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_restaurant_payments_company ON restaurant_payments (company_id, paid_at);
CREATE INDEX ix_restaurant_payments_order ON restaurant_payments (order_id);

COMMENT ON TABLE restaurant_orders IS
  'Restaurant revenue = actual order payments (restaurant_payments ledger), never product-sale logic — mirrors clinic_visits/clinic_payments exactly.';

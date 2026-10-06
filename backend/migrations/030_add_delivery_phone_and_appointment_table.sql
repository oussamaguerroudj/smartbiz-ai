-- 030_add_delivery_phone_and_appointment_table.sql
-- 1. Add customer_phone and delivery_address to restaurant_orders for delivery orders.
-- 2. Add optional table_id to appointments for table assignment.

ALTER TABLE restaurant_orders
  ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(30),
  ADD COLUMN IF NOT EXISTS delivery_address TEXT;

CREATE INDEX IF NOT EXISTS ix_restaurant_orders_phone ON restaurant_orders (company_id, customer_phone);

ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS table_id UUID REFERENCES restaurant_tables(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_appointments_table ON appointments (table_id);

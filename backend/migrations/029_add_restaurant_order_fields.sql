-- 029_add_restaurant_order_fields.sql
-- Add customer_id, customer_name, and order_type to restaurant_orders
-- to support walk-in, anonymous, and registered customers across
-- Dine-in, Takeaway, and Delivery orders.

ALTER TABLE restaurant_orders
  ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS customer_name VARCHAR(150),
  ADD COLUMN IF NOT EXISTS order_type VARCHAR(20) NOT NULL DEFAULT 'dine_in';

CREATE INDEX IF NOT EXISTS ix_restaurant_orders_customer ON restaurant_orders (customer_id);
CREATE INDEX IF NOT EXISTS ix_restaurant_orders_order_type ON restaurant_orders (company_id, order_type);

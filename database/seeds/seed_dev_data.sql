-- seed_dev_data.sql
-- Demo tenant matching the examples used throughout the Product Specification
-- (Amine Grocery, DZD currency, Whole Milk 1L etc.) — for local dev/testing only.
-- Safe to re-run: wipes and recreates the demo company only.

BEGIN;

DELETE FROM companies WHERE name = 'Amine Grocery';

WITH new_company AS (
  INSERT INTO companies (name, business_type, currency, phone, address)
  VALUES ('Amine Grocery', 'grocery', 'DZD', '+213 55 00 00 00', '123 Rue Didouche, Algiers')
  RETURNING id
),
new_owner AS (
  INSERT INTO users (company_id, name, email, password_hash, role)
  SELECT id, 'Amine K.', 'amine@smartbiz.demo',
         -- bcrypt hash of "password123" — DEV ONLY, never use in production
         '$2b$10$CwTycUXWue0Thq9StjUM0uJ8i8vC0F1FeS8yjZ8jZ8h5nO0Y0m3Ke',
         'owner'
  FROM new_company
  RETURNING company_id
),
new_supplier AS (
  INSERT INTO suppliers (company_id, name, phone)
  SELECT id, 'Central Dairy Supplier', '+213 55 11 22 33' FROM new_company
  RETURNING id, company_id
),
new_customer_1 AS (
  INSERT INTO customers (company_id, name, phone, balance_due)
  SELECT id, 'Amine K.', '+213 55 66 11 22', 0 FROM new_company
  RETURNING id, company_id
),
new_customer_2 AS (
  INSERT INTO customers (company_id, name, phone, balance_due)
  SELECT id, 'Sara B.', '+213 55 77 33 44', 6750 FROM new_company
  RETURNING id, company_id
),
new_products AS (
  INSERT INTO products (company_id, supplier_id, name, category, purchase_price, selling_price, quantity, minimum_stock)
  SELECT c.id, s.id, p.name, p.category, p.purchase_price, p.selling_price, p.quantity, p.minimum_stock
  FROM new_company c, new_supplier s,
  (VALUES
    ('Whole Milk 1L', 'Dairy', 120, 180, 42, 5),
    ('Baguette Bread', 'Bakery', 15, 25, 5, 5),
    ('Sugar 1kg', 'Grocery', 120, 160, 60, 5),
    ('Olive Oil 1L', 'Grocery', 750, 980, 0, 5)
  ) AS p(name, category, purchase_price, selling_price, quantity, minimum_stock)
  RETURNING id, company_id, name
),
new_employee AS (
  INSERT INTO employees (company_id, name, position, base_salary)
  SELECT id, 'Sara Belkacem', 'Cashier', 35000 FROM new_company
  RETURNING id, company_id
)
INSERT INTO expenses (company_id, category, description, amount, expense_date)
SELECT id, 'Electricity', 'Electricity Bill', 12000, CURRENT_DATE - INTERVAL '2 days' FROM new_company
UNION ALL
SELECT id, 'Rent', 'Shop Rent', 60000, CURRENT_DATE - INTERVAL '30 days' FROM new_company;

COMMIT;

-- Verify:
-- SELECT c.name, p.name, p.quantity FROM companies c
-- JOIN products p ON p.company_id = c.id WHERE c.name = 'Amine Grocery';

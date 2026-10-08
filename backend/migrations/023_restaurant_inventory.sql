-- 023_restaurant_inventory.sql
-- Restaurant audit Ch. 13/14 "Inventory Page" / "Inventory Stock
-- Calculation" — this table did not exist at all before this pass.
--
-- Stock is NOT a bare mutable quantity column the app can overwrite
-- freely: quantity is a denormalized cache kept in sync ONLY by
-- restaurant.repository's stock-movement functions, each of which
-- inserts a row here in the SAME transaction that updates the cache —
-- the exact pattern clinic_visits.amount_paid/payment_status already
-- uses for clinic_payments (018_add_clinic_consultation_payments.sql).
-- The ledger (this table) is the source of truth; `quantity` on
-- restaurant_inventory_items is a fast-read cache that can always be
-- recomputed as SUM(quantity_change) if it were ever in doubt.

CREATE TABLE restaurant_inventory_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name              VARCHAR(200) NOT NULL,
  category          VARCHAR(100),
  unit              VARCHAR(30) NOT NULL DEFAULT 'unit',
  quantity          NUMERIC(12,3) NOT NULL DEFAULT 0,
  minimum_stock     NUMERIC(12,3) NOT NULL DEFAULT 0,
  purchase_price    NUMERIC(12,2) NOT NULL DEFAULT 0,
  selling_price     NUMERIC(12,2),
  supplier          VARCHAR(200),
  expiration_date   DATE,
  image_url         TEXT,
  notes             TEXT,
  archived_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_restaurant_inventory_items_company ON restaurant_inventory_items (company_id, name);
CREATE INDEX ix_restaurant_inventory_items_low_stock
  ON restaurant_inventory_items (company_id)
  WHERE archived_at IS NULL;

-- Ch. 14 "Opening stock + purchases - consumption +/- adjustments =
-- current stock". movement_type 'initial' covers the opening-stock
-- entry an item is created with; 'purchase' (Ch. 15 AI-scan-confirmed
-- restocks, or a manual restock), 'consumption'/'adjustment' cover the
-- rest. quantity_change is signed (positive = stock in, negative =
-- stock out) so current stock is always SUM(quantity_change) — a
-- single formula, not different arithmetic per movement_type scattered
-- through application code.
CREATE TABLE restaurant_inventory_movements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  item_id           UUID NOT NULL REFERENCES restaurant_inventory_items(id) ON DELETE CASCADE,
  movement_type     VARCHAR(20) NOT NULL CHECK (movement_type IN ('initial', 'purchase', 'consumption', 'adjustment')),
  quantity_change   NUMERIC(12,3) NOT NULL,
  reference         VARCHAR(200),
  note              TEXT,
  created_by        UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_restaurant_inventory_movements_item ON restaurant_inventory_movements (item_id, created_at);
CREATE INDEX ix_restaurant_inventory_movements_company ON restaurant_inventory_movements (company_id);

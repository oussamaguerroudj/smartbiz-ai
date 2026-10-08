-- 025_restaurant_menu_item_ingredients.sql
-- Ch. 16 "Revenue / Cost of Goods Sold / Gross Profit / Net Profit":
-- computing COGS per order requires knowing which inventory items (and
-- how much of each) one menu item consumes. That mapping did not exist
-- anywhere in this schema — this table is it, additive to both
-- restaurant_menu_items (023) and restaurant_inventory_items (023),
-- FK'd to both rather than duplicating either.
--
-- quantity_required is in the SAME unit as the referenced
-- restaurant_inventory_items.unit — this migration does not attempt
-- unit conversion (e.g. grams vs kg); the person defining a recipe is
-- expected to use the inventory item's own unit. Documented here so
-- it's an explicit, known limitation rather than a silent wrong
-- conversion.
CREATE TABLE restaurant_menu_item_ingredients (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  menu_item_id        UUID NOT NULL REFERENCES restaurant_menu_items(id) ON DELETE CASCADE,
  inventory_item_id   UUID NOT NULL REFERENCES restaurant_inventory_items(id) ON DELETE CASCADE,
  quantity_required   NUMERIC(12,3) NOT NULL CHECK (quantity_required > 0),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ux_restaurant_menu_item_ingredients_pair
  ON restaurant_menu_item_ingredients (menu_item_id, inventory_item_id);
CREATE INDEX ix_restaurant_menu_item_ingredients_menu_item
  ON restaurant_menu_item_ingredients (menu_item_id);

-- Ch. 16 idempotency guard: when an order is completed, ingredient
-- consumption is recorded as restaurant_inventory_movements rows with
-- reference = 'order:<order_id>' (application code, not this
-- migration) — checking for an existing row with that reference before
-- deducting again is what makes "mark the same order completed twice"
-- safe, the same "don't duplicate stock changes when retried" rule
-- 023's ledger already follows for manual/AI-scan movements.
CREATE INDEX ix_restaurant_inventory_movements_reference
  ON restaurant_inventory_movements (item_id, reference);

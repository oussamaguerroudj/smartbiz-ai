-- 024_product_images.sql
-- Ch. 17/18 "Product Images — All Business Types" / "Product Card UI":
-- no products/items table anywhere in the app had an image column
-- before this migration (confirmed by grepping every migration file
-- for image_url/imageUrl). restaurant_inventory_items (023) already
-- has one — this adds the same column, same meaning (a storage key
-- from the shared images module, see src/modules/images/), to the two
-- other tables the spec calls out: CORE `products` (covers
-- superette/retail/pharmacy/clothing, all of which share this one
-- table — see products.repository.js) and `restaurant_menu_items`.

ALTER TABLE products ADD COLUMN image_url TEXT;
ALTER TABLE restaurant_menu_items ADD COLUMN image_url TEXT;

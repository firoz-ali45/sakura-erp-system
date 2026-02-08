-- ============================================================
-- RLS POLICIES FOR PURCHASE ORDERS LIST & RELATED TABLES
-- Run in Supabase SQL Editor if PO list shows "No purchase orders found"
-- despite rows existing in purchase_orders. Idempotent.
-- ============================================================

-- purchase_orders
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "po_select_anon" ON purchase_orders;
DROP POLICY IF EXISTS "po_select_authenticated" ON purchase_orders;
DROP POLICY IF EXISTS "po_insert_anon" ON purchase_orders;
DROP POLICY IF EXISTS "po_insert_authenticated" ON purchase_orders;
DROP POLICY IF EXISTS "po_update_anon" ON purchase_orders;
DROP POLICY IF EXISTS "po_update_authenticated" ON purchase_orders;
CREATE POLICY "po_select_anon" ON purchase_orders FOR SELECT TO anon USING (true);
CREATE POLICY "po_select_authenticated" ON purchase_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "po_insert_anon" ON purchase_orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "po_insert_authenticated" ON purchase_orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "po_update_anon" ON purchase_orders FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "po_update_authenticated" ON purchase_orders FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- purchase_order_items (needed for PO detail)
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "poi_select_anon" ON purchase_order_items;
DROP POLICY IF EXISTS "poi_select_authenticated" ON purchase_order_items;
DROP POLICY IF EXISTS "poi_insert_anon" ON purchase_order_items;
DROP POLICY IF EXISTS "poi_insert_authenticated" ON purchase_order_items;
DROP POLICY IF EXISTS "poi_update_anon" ON purchase_order_items;
DROP POLICY IF EXISTS "poi_update_authenticated" ON purchase_order_items;
CREATE POLICY "poi_select_anon" ON purchase_order_items FOR SELECT TO anon USING (true);
CREATE POLICY "poi_select_authenticated" ON purchase_order_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "poi_insert_anon" ON purchase_order_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "poi_insert_authenticated" ON purchase_order_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "poi_update_anon" ON purchase_order_items FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "poi_update_authenticated" ON purchase_order_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- suppliers (joined in PO list: supplier:suppliers(*))
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "suppliers_select_anon" ON suppliers;
DROP POLICY IF EXISTS "suppliers_select_authenticated" ON suppliers;
CREATE POLICY "suppliers_select_anon" ON suppliers FOR SELECT TO anon USING (true);
CREATE POLICY "suppliers_select_authenticated" ON suppliers FOR SELECT TO authenticated USING (true);

-- inventory_items (joined in PO items: item:inventory_items(*))
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "inv_items_select_anon" ON inventory_items;
DROP POLICY IF EXISTS "inv_items_select_authenticated" ON inventory_items;
CREATE POLICY "inv_items_select_anon" ON inventory_items FOR SELECT TO anon USING (true);
CREATE POLICY "inv_items_select_authenticated" ON inventory_items FOR SELECT TO authenticated USING (true);

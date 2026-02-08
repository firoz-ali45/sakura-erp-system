-- ============================================================
-- RLS POLICIES FOR inventory_locations
-- Run this in Supabase SQL Editor after enabling RLS.
-- Without these, SELECT returns no rows (list empty) and INSERT fails.
-- ============================================================

ALTER TABLE inventory_locations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (so script is idempotent)
DROP POLICY IF EXISTS "inventory_locations_select_anon" ON inventory_locations;
DROP POLICY IF EXISTS "inventory_locations_select_authenticated" ON inventory_locations;
DROP POLICY IF EXISTS "inventory_locations_insert_anon" ON inventory_locations;
DROP POLICY IF EXISTS "inventory_locations_insert_authenticated" ON inventory_locations;
DROP POLICY IF EXISTS "inventory_locations_update_anon" ON inventory_locations;
DROP POLICY IF EXISTS "inventory_locations_update_authenticated" ON inventory_locations;

-- SELECT: so UI can list locations and dropdowns can load
CREATE POLICY "inventory_locations_select_anon"
  ON inventory_locations FOR SELECT TO anon
  USING (true);

CREATE POLICY "inventory_locations_select_authenticated"
  ON inventory_locations FOR SELECT TO authenticated
  USING (true);

-- INSERT: so "Create Location" works
CREATE POLICY "inventory_locations_insert_anon"
  ON inventory_locations FOR INSERT TO anon
  WITH CHECK (true);

CREATE POLICY "inventory_locations_insert_authenticated"
  ON inventory_locations FOR INSERT TO authenticated
  WITH CHECK (true);

-- UPDATE: so Edit and Disable work
CREATE POLICY "inventory_locations_update_anon"
  ON inventory_locations FOR UPDATE TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "inventory_locations_update_authenticated"
  ON inventory_locations FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- Optional: DELETE if you ever need to remove rows (else use is_active = false)
-- CREATE POLICY "inventory_locations_delete_anon" ON inventory_locations FOR DELETE TO anon USING (true);
-- CREATE POLICY "inventory_locations_delete_authenticated" ON inventory_locations FOR DELETE TO authenticated USING (true);

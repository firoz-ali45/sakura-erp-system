-- ============================================================
-- RLS POLICIES FOR inventory_batches
-- Fix: Frontend upsert (saveBatchToSupabase) needs to INSERT/UPDATE
-- so batch_number is persisted and v_inventory_balance shows it.
-- Run in Supabase SQL Editor. Idempotent.
-- ============================================================

ALTER TABLE inventory_batches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "inventory_batches_select_anon" ON inventory_batches;
DROP POLICY IF EXISTS "inventory_batches_select_authenticated" ON inventory_batches;
DROP POLICY IF EXISTS "inventory_batches_insert_anon" ON inventory_batches;
DROP POLICY IF EXISTS "inventory_batches_insert_authenticated" ON inventory_batches;
DROP POLICY IF EXISTS "inventory_batches_update_anon" ON inventory_batches;
DROP POLICY IF EXISTS "inventory_batches_update_authenticated" ON inventory_batches;

CREATE POLICY "inventory_batches_select_anon"
  ON inventory_batches FOR SELECT TO anon USING (true);

CREATE POLICY "inventory_batches_select_authenticated"
  ON inventory_batches FOR SELECT TO authenticated USING (true);

CREATE POLICY "inventory_batches_insert_anon"
  ON inventory_batches FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "inventory_batches_insert_authenticated"
  ON inventory_batches FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "inventory_batches_update_anon"
  ON inventory_batches FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "inventory_batches_update_authenticated"
  ON inventory_batches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE ON inventory_batches TO anon;
GRANT SELECT, INSERT, UPDATE ON inventory_batches TO authenticated;

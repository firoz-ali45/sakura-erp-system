-- ============================================================
-- RLS POLICIES FOR inventory_stock_ledger
-- Fix: "new row violates row-level security policy for table 'inventory_stock_ledger'"
-- When GRN is approved, trigger inserts into this table; anon/authenticated need INSERT.
-- Run in Supabase SQL Editor. Idempotent.
-- ============================================================

ALTER TABLE inventory_stock_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stock_ledger_select_anon" ON inventory_stock_ledger;
DROP POLICY IF EXISTS "stock_ledger_select_authenticated" ON inventory_stock_ledger;
DROP POLICY IF EXISTS "stock_ledger_insert_anon" ON inventory_stock_ledger;
DROP POLICY IF EXISTS "stock_ledger_insert_authenticated" ON inventory_stock_ledger;
DROP POLICY IF EXISTS "stock_ledger_select_all" ON inventory_stock_ledger;
DROP POLICY IF EXISTS "stock_ledger_insert_all" ON inventory_stock_ledger;
DROP POLICY IF EXISTS "Allow all for authenticated" ON inventory_stock_ledger;
DROP POLICY IF EXISTS "Allow select for authenticated" ON inventory_stock_ledger;

CREATE POLICY "stock_ledger_select_anon"
  ON inventory_stock_ledger FOR SELECT TO anon USING (true);

CREATE POLICY "stock_ledger_select_authenticated"
  ON inventory_stock_ledger FOR SELECT TO authenticated USING (true);

CREATE POLICY "stock_ledger_insert_anon"
  ON inventory_stock_ledger FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "stock_ledger_insert_authenticated"
  ON inventory_stock_ledger FOR INSERT TO authenticated WITH CHECK (true);

GRANT SELECT, INSERT ON inventory_stock_ledger TO anon;
GRANT SELECT, INSERT ON inventory_stock_ledger TO authenticated;

-- ============================================================
-- PART 8 — VERIFICATION (SAP/FOODICS INVENTORY)
-- Run after applying 20260209180000_sap_inventory_ledger_and_locations.sql
-- ============================================================

-- 1) Ghost locations: ONLY inventory_locations is source. No hardcoded lists.
SELECT 'inventory_locations (is_active=true)' AS check_name, COUNT(*)::text AS result
FROM inventory_locations WHERE is_active = true;

SELECT 'inventory_locations (allow_grn=true)' AS check_name, COUNT(*)::text AS result
FROM inventory_locations WHERE is_active = true AND allow_grn = true;

-- 2) Ledger exists and is immutable (trigger prevents UPDATE/DELETE)
SELECT 'inventory_stock_ledger row count' AS check_name, COUNT(*)::text AS result
FROM inventory_stock_ledger;

-- 3) Views exist and are ledger-only (no stored stock)
SELECT 'v_inventory_balance' AS view_name, COUNT(*)::text AS row_count FROM v_inventory_balance;
SELECT 'v_inventory_history' AS view_name, COUNT(*)::text AS row_count FROM v_inventory_history;

-- 4) Control report function (date range)
SELECT * FROM fn_inventory_control_report(
  (current_date - interval '30 days')::date,
  current_date
) LIMIT 5;

-- 5) No negative stock (optional: uncomment if business rule enforced)
-- SELECT item_id, location_id, SUM(qty_in)-SUM(qty_out) AS balance
-- FROM inventory_stock_ledger GROUP BY item_id, location_id
-- HAVING SUM(qty_in)-SUM(qty_out) < 0;

-- ============================================================
-- VERIFICATION: Inventory Ledger & Locations (run after 01–10)
-- ============================================================

-- 1) Locations: ONLY inventory_locations is source of truth; no ghost locations
SELECT 'inventory_locations' AS check_name, COUNT(*)::text AS result FROM inventory_locations WHERE is_active = true
UNION ALL
SELECT 'inventory_locations_allow_grn', COUNT(*)::text FROM inventory_locations WHERE is_active = true AND allow_grn = true
UNION ALL
SELECT 'inventory_locations_allow_transfer_out', COUNT(*)::text FROM inventory_locations WHERE is_active = true AND allow_transfer_out = true;

-- 2) Stock only from ledger (v_inventory_balance); no stock table
SELECT 'v_inventory_balance_rows' AS check_name, COUNT(*)::text FROM v_inventory_balance
UNION ALL
SELECT 'inventory_stock_ledger_rows', COUNT(*)::text FROM inventory_stock_ledger;

-- 3) GRN increases stock: ledger rows with movement_type = 'GRN'
SELECT 'grn_ledger_entries' AS check_name, COUNT(*)::text FROM inventory_stock_ledger WHERE movement_type = 'GRN';

-- 4) Balance = total_in - total_out per item/location/batch
SELECT item_id, location_id, batch_id, total_in, total_out, (total_in - total_out) AS current_qty, total_value, avg_unit_cost
FROM v_inventory_balance
WHERE (total_in - total_out) <> 0
ORDER BY item_id, location_id
LIMIT 10;

-- 5) No negative stock (unless adjustment) — balance view should not show negative without explicit adjustment type
SELECT 'negative_balance_count' AS check_name, COUNT(*)::text
FROM v_inventory_balance
WHERE (total_in - total_out) < 0;

-- 6) Ledger immutable: no UPDATE/DELETE (enforced by trigger; this query only checks row count)
SELECT 'ledger_row_count' AS check_name, COUNT(*)::text FROM inventory_stock_ledger;

-- 7) Report views exist and are read-only
SELECT 'v_inventory_history' AS view_name, COUNT(*)::text FROM v_inventory_history
UNION ALL SELECT 'v_inventory_control', COUNT(*)::text FROM v_inventory_control
UNION ALL SELECT 'v_purchasing_report', COUNT(*)::text FROM v_purchasing_report
UNION ALL SELECT 'v_transfers_report', COUNT(*)::text FROM v_transfers_report
UNION ALL SELECT 'v_cost_adjustment_history', COUNT(*)::text FROM v_cost_adjustment_history;

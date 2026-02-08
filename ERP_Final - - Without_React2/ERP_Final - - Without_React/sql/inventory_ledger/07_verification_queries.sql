-- ============================================================
-- VERIFICATION QUERIES (MANDATORY)
-- Run after deploying 01–06. No sample data inserted.
-- ============================================================

-- 1) Stock by item & location
-- SELECT item_id, location_id, current_qty, total_value, avg_unit_cost
-- FROM v_inventory_balance
-- WHERE current_qty <> 0
-- ORDER BY item_id, location_id;

-- 2) Ledger trail for one item (replace :item_id with actual UUID)
-- SELECT id, item_id, location_id, batch_id, qty_in, qty_out, unit_cost, total_cost,
--        movement_type, reference_type, reference_id, created_by, created_at
-- FROM inventory_stock_ledger
-- WHERE item_id = :item_id
-- ORDER BY created_at, id;

-- 3) GRN → stock increase proof (ledger rows created on GRN approval)
-- SELECT isl.id, isl.item_id, isl.location_id, isl.qty_in, isl.unit_cost, isl.total_cost,
--        isl.movement_type, isl.reference_type, isl.reference_id, isl.created_at,
--        gi.grn_number, gi.status
-- FROM inventory_stock_ledger isl
-- JOIN grn_inspections gi ON gi.id::text = isl.reference_id AND isl.reference_type = 'GRN'
-- WHERE isl.movement_type = 'GRN'
-- ORDER BY isl.created_at DESC
-- LIMIT 20;

-- 4) Transfer → warehouse ↓ branch ↑ (when transfer table exists)
-- Expect: qty_out from source (warehouse), qty_in to destination (branch), same cost
-- SELECT * FROM v_inventory_movements
-- WHERE movement_type IN ('TRANSFER_OUT', 'TRANSFER_IN')
-- ORDER BY created_at DESC;

-- 5) Production → RM ↓ FG ↑ (when production tables exist)
-- Expect: PRODUCTION_CONSUMPTION (qty_out) for RM, PRODUCTION_OUTPUT (qty_in) for FG
-- SELECT * FROM v_inventory_movements
-- WHERE movement_type IN ('PRODUCTION_CONSUMPTION', 'PRODUCTION_OUTPUT')
-- ORDER BY created_at DESC;

-- Executable verification (run as-is)
SELECT 'v_inventory_balance row count' AS check_name, COUNT(*)::text AS result FROM v_inventory_balance
UNION ALL
SELECT 'inventory_stock_ledger row count', COUNT(*)::text FROM inventory_stock_ledger
UNION ALL
SELECT 'inventory_locations count', COUNT(*)::text FROM inventory_locations
UNION ALL
SELECT 'inventory_batches count', COUNT(*)::text FROM inventory_batches;

-- ============================================================
-- MODULE 5: INVENTORY BALANCE VIEW (READ-ONLY)
-- MODULE 6: INVENTORY MOVEMENT HISTORY
-- No data stored — pure calculation from ledger.
-- ============================================================

-- ----- v_inventory_balance: GROUP BY item_id, location_id, batch_id -----
DROP VIEW IF EXISTS v_inventory_balance CASCADE;
CREATE VIEW v_inventory_balance AS
SELECT
  isl.item_id,
  isl.location_id,
  isl.batch_id,
  SUM(isl.qty_in)   AS total_in,
  SUM(isl.qty_out) AS total_out,
  SUM(isl.qty_in) - SUM(isl.qty_out) AS current_qty,
  SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) AS total_value,
  CASE
    WHEN SUM(isl.qty_in) - SUM(isl.qty_out) > 0
    THEN SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END)
         / NULLIF(SUM(isl.qty_in) - SUM(isl.qty_out), 0)
    ELSE 0
  END AS avg_unit_cost
FROM inventory_stock_ledger isl
GROUP BY isl.item_id, isl.location_id, isl.batch_id;

COMMENT ON VIEW v_inventory_balance IS 'Read-only. Stock by item, location, batch. current_qty = total_in - total_out. No data stored.';

-- ----- v_inventory_movements: Audit / debugging / reconciliation -----
DROP VIEW IF EXISTS v_inventory_movements CASCADE;
CREATE VIEW v_inventory_movements AS
SELECT
  isl.id,
  isl.item_id,
  isl.location_id,
  isl.batch_id,
  isl.qty_in,
  isl.qty_out,
  isl.unit_cost,
  isl.total_cost,
  isl.movement_type,
  isl.reference_type,
  isl.reference_id,
  isl.created_by,
  isl.created_at
FROM inventory_stock_ledger isl
ORDER BY isl.created_at DESC, isl.id;

COMMENT ON VIEW v_inventory_movements IS 'Movement history for audit, debugging, finance reconciliation.';

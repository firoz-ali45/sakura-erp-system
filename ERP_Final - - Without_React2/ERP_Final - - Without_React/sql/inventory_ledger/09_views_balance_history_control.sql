-- ============================================================
-- v_inventory_balance (enhanced), v_inventory_history, v_inventory_control
-- All derived ONLY from ledger. No stored stock.
-- Run 08_ledger_enum_and_columns.sql first (adds reason, notes, submitted_by, submitted_at).
-- ============================================================

-- ----- 1) v_inventory_balance: real-time balance with Item Name, SKU, Storage Unit, Location, Batch -----
DROP VIEW IF EXISTS v_inventory_balance CASCADE;
CREATE VIEW v_inventory_balance AS
SELECT
  b.item_id,
  b.location_id,
  b.batch_id,
  ii.name AS item_name,
  ii.sku,
  ii.storage_unit,
  il.location_code,
  il.location_name AS location,
  ib.batch_number AS batch,
  b.total_in,
  b.total_out,
  (b.total_in - b.total_out) AS current_qty,
  b.avg_unit_cost,
  b.total_value
FROM (
  SELECT
    isl.item_id,
    isl.location_id,
    isl.batch_id,
    SUM(isl.qty_in) AS total_in,
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
  GROUP BY isl.item_id, isl.location_id, isl.batch_id
) b
LEFT JOIN inventory_items ii ON ii.id = b.item_id AND (COALESCE(ii.deleted, false) = false)
LEFT JOIN inventory_locations il ON il.id = b.location_id
LEFT JOIN inventory_batches ib ON ib.id = b.batch_id;

COMMENT ON VIEW v_inventory_balance IS 'Real-time balance from ledger only. Item Name, SKU, Storage Unit, Location, Batch, Current Qty, Avg Unit Cost, Total Value.';

-- ----- 2) v_inventory_history: ledger-level audit -----
DROP VIEW IF EXISTS v_inventory_history CASCADE;
CREATE VIEW v_inventory_history AS
SELECT
  isl.id,
  isl.item_id,
  isl.location_id,
  isl.batch_id,
  ii.name AS item_name,
  ii.sku,
  ii.barcode,
  ii.storage_unit,
  il.location_name AS location,
  isl.movement_type AS transaction_type,
  isl.reference_type || ' ' || COALESCE(isl.reference_id::text, '') AS reference,
  isl.qty_in,
  isl.qty_out,
  isl.unit_cost,
  isl.total_cost AS cost,
  isl.reason,
  isl.notes,
  isl.created_by AS created_by,
  isl.submitted_by AS submitted_by,
  isl.submitted_at AS submitted_at,
  isl.created_at
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (ii.deleted IS NOT TRUE)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
ORDER BY isl.created_at DESC, isl.id;

COMMENT ON VIEW v_inventory_history IS 'Ledger-level audit. Item Name, SKU, Barcode, Storage Unit, Location, Transaction Type, Reference, Qty, Cost, Reason, Notes, Created By, Submitted By, Submitted At.';

-- ----- 3) v_inventory_control: period-based (date range) -----
-- Opening = balance at start of period; Closing = balance at end; movements in between by type.
DROP VIEW IF EXISTS v_inventory_control CASCADE;
CREATE VIEW v_inventory_control AS
WITH period_ledger AS (
  SELECT
    isl.item_id,
    isl.location_id,
    isl.movement_type,
    isl.qty_in,
    isl.qty_out,
    isl.unit_cost,
    isl.total_cost,
    isl.created_at::date AS movement_date
  FROM inventory_stock_ledger isl
),
by_item_location_date AS (
  SELECT
    item_id,
    location_id,
    movement_date,
    movement_type,
    SUM(qty_in) AS qty_in,
    SUM(qty_out) AS qty_out,
    SUM(total_cost) AS total_cost
  FROM period_ledger
  GROUP BY item_id, location_id, movement_date, movement_type
)
SELECT
  b.item_id,
  b.location_id,
  b.movement_date AS report_date,
  ii.name AS item_name,
  ii.sku,
  il.location_name AS location,
  b.movement_type,
  b.qty_in,
  b.qty_out,
  b.total_cost
FROM by_item_location_date b
LEFT JOIN inventory_items ii ON ii.id = b.item_id AND (COALESCE(ii.deleted, false) = false)
LEFT JOIN inventory_locations il ON il.id = b.location_id;

COMMENT ON VIEW v_inventory_control IS 'Period-based: movements by item, location, date, type. Use in app with date filter to compute Opening/Closing and buckets.';

-- Materialized helper for control report (optional): use in app with date range
-- Opening = SUM(ledger before from_date), Closing = SUM(ledger before to_date+1), IN/OUT by type in range
DROP VIEW IF EXISTS v_inventory_control_summary CASCADE;
CREATE VIEW v_inventory_control_summary AS
SELECT
  isl.item_id,
  isl.location_id,
  isl.movement_type,
  COUNT(*) AS row_count,
  SUM(isl.qty_in) AS total_qty_in,
  SUM(isl.qty_out) AS total_qty_out,
  SUM(isl.total_cost) AS total_cost
FROM inventory_stock_ledger isl
GROUP BY isl.item_id, isl.location_id, isl.movement_type;

COMMENT ON VIEW v_inventory_control_summary IS 'Aggregate by item, location, movement_type. Filter by created_at in app for period.';

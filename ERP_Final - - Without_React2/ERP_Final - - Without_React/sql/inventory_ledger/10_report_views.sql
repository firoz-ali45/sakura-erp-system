-- ============================================================
-- Report views: PO, Transfer Orders, Transfers, Purchasing, Cost Adjustment
-- Read-only. Join inventory_items + inventory_locations. No stored stock; use ledger for cost.
-- Run 08_ledger_enum_and_columns.sql first (adds reason, notes, submitted_by, submitted_at to ledger).
-- ============================================================

-- v_purchase_orders_report
DROP VIEW IF EXISTS v_purchase_orders_report CASCADE;
CREATE VIEW v_purchase_orders_report AS
SELECT
  po.id,
  po.po_number,
  po.supplier_id,
  po.supplier_name,
  po.order_date,
  po.status,
  po.destination,
  po.total_amount,
  po.notes,
  il.id AS location_id,
  il.location_code,
  il.location_name
FROM purchase_orders po
LEFT JOIN inventory_locations il ON il.is_active = true
  AND (il.location_name || ' (' || il.location_code || ')') = po.destination
WHERE COALESCE(po.deleted, false) = false;

COMMENT ON VIEW v_purchase_orders_report IS 'PO report. Joins inventory_locations for destination. Read-only.';

-- v_transfer_orders_report (optional: run only if transfer_orders table exists)
-- Uncomment and run when transfer_orders exists with source_location_id, dest_location_id:
/*
DROP VIEW IF EXISTS v_transfer_orders_report CASCADE;
CREATE VIEW v_transfer_orders_report AS
SELECT t.id, t.transfer_number, t.source_location_id, t.dest_location_id, t.status, t.transfer_date,
  sl.location_code AS source_code, sl.location_name AS source_name,
  dl.location_code AS dest_code, dl.location_name AS dest_name
FROM transfer_orders t
LEFT JOIN inventory_locations sl ON sl.id = t.source_location_id
LEFT JOIN inventory_locations dl ON dl.id = t.dest_location_id;
*/
DROP VIEW IF EXISTS v_transfer_orders_report CASCADE;
CREATE VIEW v_transfer_orders_report AS
SELECT
  NULL::uuid AS id,
  NULL::text AS transfer_number,
  NULL::uuid AS source_location_id,
  NULL::uuid AS dest_location_id,
  NULL::text AS status,
  NULL::date AS transfer_date,
  NULL::text AS source_code,
  NULL::text AS source_name,
  NULL::text AS dest_code,
  NULL::text AS dest_name
WHERE false;
COMMENT ON VIEW v_transfer_orders_report IS 'Placeholder until transfer_orders table exists. Replace with real SELECT from transfer_orders + inventory_locations.';

-- v_transfers_report (ledger movements of type TRANSFER_IN / TRANSFER_OUT)
DROP VIEW IF EXISTS v_transfers_report CASCADE;
CREATE VIEW v_transfers_report AS
SELECT
  isl.id,
  isl.item_id,
  isl.location_id,
  isl.movement_type,
  isl.qty_in,
  isl.qty_out,
  isl.unit_cost,
  isl.total_cost,
  isl.reference_type,
  isl.reference_id,
  isl.created_at,
  ii.name AS item_name,
  ii.sku,
  il.location_name,
  il.location_code
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (COALESCE(ii.deleted, false) = false)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
WHERE isl.movement_type IN ('TRANSFER_IN', 'TRANSFER_OUT')
ORDER BY isl.created_at DESC;

COMMENT ON VIEW v_transfers_report IS 'Transfer movements from ledger only.';

-- v_purchasing_report
DROP VIEW IF EXISTS v_purchasing_report CASCADE;
CREATE VIEW v_purchasing_report AS
SELECT
  pi.id,
  pi.invoice_number,
  pi.purchasing_number,
  pi.grn_id,
  pi.grn_number,
  pi.purchase_order_id,
  pi.purchase_order_number,
  pi.supplier_id,
  pi.supplier_name,
  pi.invoice_date,
  pi.receiving_location,
  pi.subtotal,
  pi.tax_amount,
  pi.grand_total,
  pi.status,
  il.id AS location_id,
  il.location_code,
  il.location_name
FROM purchasing_invoices pi
LEFT JOIN inventory_locations il ON il.is_active = true
  AND (il.location_name || ' (' || il.location_code || ')') = pi.receiving_location
WHERE COALESCE(pi.deleted, false) = false;

COMMENT ON VIEW v_purchasing_report IS 'Purchasing invoices. Joins inventory_locations. Read-only.';

-- v_cost_adjustment_history (ledger rows: ADJUSTMENT, COST_ADJUSTMENT, COUNT_VARIANCE)
DROP VIEW IF EXISTS v_cost_adjustment_history CASCADE;
CREATE VIEW v_cost_adjustment_history AS
SELECT
  isl.id,
  isl.item_id,
  isl.location_id,
  isl.movement_type,
  isl.qty_in,
  isl.qty_out,
  isl.unit_cost,
  isl.total_cost,
  isl.reason,
  isl.notes,
  isl.created_by,
  isl.submitted_by,
  isl.submitted_at,
  isl.created_at,
  ii.name AS item_name,
  ii.sku,
  il.location_name,
  il.location_code
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (COALESCE(ii.deleted, false) = false)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
WHERE isl.movement_type IN ('ADJUSTMENT', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'COST_ADJUSTMENT', 'COUNT_VARIANCE')
ORDER BY isl.created_at DESC;

COMMENT ON VIEW v_cost_adjustment_history IS 'Cost and count adjustments from ledger only.';

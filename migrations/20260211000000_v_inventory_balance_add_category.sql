-- Add category to v_inventory_balance (from inventory_items)
DROP VIEW IF EXISTS v_inventory_balance CASCADE;
CREATE VIEW v_inventory_balance AS
SELECT
  b.item_id,
  b.location_id,
  b.batch_id,
  ii.name AS item_name,
  ii.sku,
  ii.storage_unit,
  ii.category,
  il.location_name,
  ib.batch_number AS batch_no,
  b.total_in,
  b.total_out,
  (b.total_in - b.total_out) AS current_qty,
  b.avg_cost,
  b.total_value
FROM (
  SELECT isl.item_id, isl.location_id, isl.batch_id,
    SUM(isl.qty_in) AS total_in,
    SUM(isl.qty_out) AS total_out,
    SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) AS total_value,
    CASE WHEN SUM(isl.qty_in) - SUM(isl.qty_out) > 0
      THEN SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) / NULLIF(SUM(isl.qty_in) - SUM(isl.qty_out), 0)
      ELSE 0 END AS avg_cost
  FROM inventory_stock_ledger isl
  GROUP BY isl.item_id, isl.location_id, isl.batch_id
) b
LEFT JOIN inventory_items ii ON ii.id = b.item_id AND COALESCE(ii.deleted, false) = false
LEFT JOIN inventory_locations il ON il.id = b.location_id
LEFT JOIN inventory_batches ib ON ib.id = b.batch_id;

COMMENT ON VIEW v_inventory_balance IS 'Ledger-only balance. Item, SKU, category, location, batch, current_qty, avg_cost, total_value.';

-- Cost Adjustment History: add Name, SKU, Barcode, Storage Unit, Branch, Reference,
-- Original Cost per Unit, New Cost per Unit, Created By, Submitted By, Submitted At
DROP VIEW IF EXISTS v_cost_adjustment_history CASCADE;
CREATE VIEW v_cost_adjustment_history AS
SELECT
  isl.id,
  isl.item_id,
  isl.location_id,
  ii.name AS item_name,
  ii.sku,
  ii.barcode,
  ii.storage_unit,
  il.location_name AS branch,
  isl.reference_type || ' ' || COALESCE(isl.reference_id::text, '') AS reference,
  LAG(isl.unit_cost) OVER (PARTITION BY isl.item_id, isl.location_id ORDER BY isl.created_at) AS original_cost_per_unit,
  isl.unit_cost AS new_cost_per_unit,
  isl.created_by,
  isl.submitted_by,
  isl.submitted_at,
  isl.movement_type,
  isl.qty_in,
  isl.qty_out,
  isl.total_cost,
  isl.reason,
  isl.notes,
  isl.created_at
FROM inventory_stock_ledger isl
LEFT JOIN inventory_items ii ON ii.id = isl.item_id AND (ii.deleted IS NOT TRUE)
LEFT JOIN inventory_locations il ON il.id = isl.location_id
WHERE isl.movement_type::text = ANY (ARRAY['ADJUSTMENT','ADJUSTMENT_IN','ADJUSTMENT_OUT','COST_ADJUSTMENT','COUNT_VARIANCE','WASTE','EXPIRY','EXPIRED'])
ORDER BY isl.created_at DESC;

COMMENT ON VIEW v_cost_adjustment_history IS 'Cost adjustment history. Name, SKU, Barcode, Storage Unit, Branch, Reference, Original/New Cost, Created By, Submitted By, Submitted At.';

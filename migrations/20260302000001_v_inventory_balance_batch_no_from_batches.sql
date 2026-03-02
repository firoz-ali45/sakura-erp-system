-- Stock Overview: show batch_number (BATCH-GRN-xxx) instead of ---
-- v_inventory_balance used _deprecated_inventory_batches; ledger.batch_id now references public.batches
-- Use public.batches so batch_no is populated from batches.batch_number

DROP VIEW IF EXISTS public.v_inventory_balance CASCADE;

CREATE VIEW public.v_inventory_balance AS
SELECT
  b.item_id,
  b.location_id,
  b.batch_id,
  ii.name AS item_name,
  ii.sku,
  ii.storage_unit,
  ii.category,
  il.location_name,
  COALESCE(bat.batch_number, ib.batch_number) AS batch_no,
  b.total_in,
  b.total_out,
  (b.total_in - b.total_out) AS current_qty,
  b.avg_cost,
  b.total_value
FROM (
  SELECT
    isl.item_id,
    isl.location_id,
    isl.batch_id,
    sum(isl.qty_in) AS total_in,
    sum(isl.qty_out) AS total_out,
    sum(CASE WHEN isl.qty_in > 0::numeric THEN isl.total_cost ELSE -isl.total_cost END) AS total_value,
    CASE
      WHEN (sum(isl.qty_in) - sum(isl.qty_out)) > 0::numeric
      THEN sum(CASE WHEN isl.qty_in > 0::numeric THEN isl.total_cost ELSE -isl.total_cost END)
           / NULLIF(sum(isl.qty_in) - sum(isl.qty_out), 0::numeric)
      ELSE 0::numeric
    END AS avg_cost
  FROM inventory_stock_ledger isl
  GROUP BY isl.item_id, isl.location_id, isl.batch_id
) b
LEFT JOIN inventory_items ii ON ii.id = b.item_id AND COALESCE(ii.deleted, false) = false
LEFT JOIN inventory_locations il ON il.id = b.location_id
LEFT JOIN public.batches bat ON bat.id = b.batch_id
LEFT JOIN _deprecated_inventory_batches ib ON ib.id = b.batch_id;

COMMENT ON VIEW public.v_inventory_balance IS 'Balance by item/location/batch; batch_no from public.batches (then legacy) for Stock Overview';

GRANT SELECT ON public.v_inventory_balance TO authenticated, anon;

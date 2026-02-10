-- ============================================================
-- Create fn_inventory_control_report(date, date) in Supabase
-- Run this in SQL Editor if the function is missing (e.g. migration not applied).
-- Requires: inventory_stock_ledger, inventory_items, inventory_locations.
-- ============================================================

CREATE OR REPLACE FUNCTION fn_inventory_control_report(p_from_date date, p_to_date date)
RETURNS TABLE (
  item_id uuid,
  location_id uuid,
  item_name text,
  sku text,
  location_name text,
  opening_qty numeric,
  opening_cost numeric,
  purchasing_qty numeric,
  transfer_in_qty numeric,
  production_in_qty numeric,
  return_qty numeric,
  transfer_out_qty numeric,
  consumption_qty numeric,
  waste_qty numeric,
  adjustment_qty numeric,
  total_in numeric,
  total_out numeric,
  closing_qty numeric,
  closing_cost numeric
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN QUERY
  WITH
  opening AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_in) - SUM(isl.qty_out) AS qty,
      SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) AS cost
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date < p_from_date
    GROUP BY isl.item_id, isl.location_id
  ),
  period_in AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text = 'GRN') AS grn_qty,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text IN ('TRANSFER_IN')) AS transfer_in,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text IN ('PRODUCTION_IN','PRODUCTION_OUTPUT')) AS production_in,
      SUM(isl.qty_in) FILTER (WHERE isl.movement_type::text IN ('RETURN_FROM_ORDER','RETURN_TO_SUPPLIER','RETURN')) AS return_in,
      SUM(isl.qty_in) AS total_in
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date >= p_from_date AND isl.created_at::date <= p_to_date
    GROUP BY isl.item_id, isl.location_id
  ),
  period_out AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('TRANSFER_OUT')) AS transfer_out,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('SALE_CONSUMPTION','SALE')) AS consumption,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('WASTE','SCRAP','EXPIRY','EXPIRED')) AS waste,
      SUM(isl.qty_out) FILTER (WHERE isl.movement_type::text IN ('ADJUSTMENT','ADJUSTMENT_OUT','COUNT_VARIANCE')) AS adjustment_out,
      SUM(isl.qty_out) AS total_out
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date >= p_from_date AND isl.created_at::date <= p_to_date
    GROUP BY isl.item_id, isl.location_id
  ),
  closing AS (
    SELECT isl.item_id, isl.location_id,
      SUM(isl.qty_in) - SUM(isl.qty_out) AS qty,
      SUM(CASE WHEN isl.qty_in > 0 THEN isl.total_cost ELSE -isl.total_cost END) AS cost
    FROM inventory_stock_ledger isl
    WHERE isl.created_at::date <= p_to_date
    GROUP BY isl.item_id, isl.location_id
  ),
  keys AS (
    SELECT DISTINCT k.ciid, k.clid
    FROM (
      SELECT o.item_id AS ciid, o.location_id AS clid FROM opening o
      UNION SELECT pin.item_id, pin.location_id FROM period_in pin
      UNION SELECT pout.item_id, pout.location_id FROM period_out pout
      UNION SELECT c.item_id, c.location_id FROM closing c
    ) k
  )
  SELECT
    k.ciid,
    k.clid,
    ii.name,
    ii.sku,
    il.location_name,
    COALESCE(o.qty, 0),
    COALESCE(o.cost, 0),
    COALESCE(pi.grn_qty, 0),
    COALESCE(pi.transfer_in, 0),
    COALESCE(pi.production_in, 0),
    COALESCE(pi.return_in, 0),
    COALESCE(po.transfer_out, 0),
    COALESCE(po.consumption, 0),
    COALESCE(po.waste, 0),
    COALESCE(po.adjustment_out, 0),
    COALESCE(pi.total_in, 0),
    COALESCE(po.total_out, 0),
    COALESCE(c.qty, 0),
    COALESCE(c.cost, 0)
  FROM keys k
  LEFT JOIN opening o ON o.item_id = k.ciid AND o.location_id = k.clid
  LEFT JOIN period_in pi ON pi.item_id = k.ciid AND pi.location_id = k.clid
  LEFT JOIN period_out po ON po.item_id = k.ciid AND po.location_id = k.clid
  LEFT JOIN closing c ON c.item_id = k.ciid AND c.location_id = k.clid
  LEFT JOIN inventory_items ii ON ii.id = k.ciid AND (ii.deleted IS NOT TRUE)
  LEFT JOIN inventory_locations il ON il.id = k.clid;
END;
$$;

COMMENT ON FUNCTION fn_inventory_control_report(date, date) IS 'Date-range inventory control. Opening/In/Out/Closing from ledger only.';

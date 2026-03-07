-- v_transfer_orders_full: add user display names (single source of truth for TO list/detail)
-- So TO list and detail show names instead of UUIDs for Created by / Approved by / Declined by.
DROP VIEW IF EXISTS public.v_transfer_orders_full;

CREATE VIEW public.v_transfer_orders_full AS
SELECT
  t.id,
  t.transfer_number,
  t.from_location_id,
  t.to_location_id,
  fl.location_code AS from_code,
  fl.location_name AS from_name,
  tl.location_code AS to_code,
  tl.location_name AS to_name,
  t.status,
  t.approval_level_required,
  t.current_approval_level,
  t.requested_by,
  public.fn_user_display_name(t.requested_by) AS requested_by_name,
  t.approved_by_level1,
  public.fn_user_display_name(t.approved_by_level1) AS approved_by_level1_name,
  t.approved_by_level2,
  public.fn_user_display_name(t.approved_by_level2) AS approved_by_level2_name,
  t.rejected_by,
  public.fn_user_display_name(t.rejected_by) AS rejected_by_name,
  t.created_at,
  t.updated_at,
  t.remarks,
  t.business_date,
  COALESCE(agg.requested_total, 0::numeric) AS requested_total,
  COALESCE(agg.dispatched_total, 0::numeric) AS dispatched_total,
  COALESCE(agg.received_total, 0::numeric) AS received_total,
  COALESCE(agg.variance_total, 0::numeric) AS variance_total
FROM transfer_orders t
LEFT JOIN inventory_locations fl ON fl.id = t.from_location_id
LEFT JOIN inventory_locations tl ON tl.id = t.to_location_id
LEFT JOIN (
  SELECT
    transfer_order_items.transfer_id,
    sum(transfer_order_items.requested_qty) AS requested_total,
    sum(transfer_order_items.dispatched_qty) AS dispatched_total,
    sum(transfer_order_items.received_qty) AS received_total,
    sum(transfer_order_items.variance_qty) AS variance_total
  FROM transfer_order_items
  GROUP BY transfer_order_items.transfer_id
) agg ON agg.transfer_id = t.id
ORDER BY t.created_at DESC;

-- Transfer "Created by" showing "Not available": add created_by_name via fn_user_display_name (unified data governance).
DROP VIEW IF EXISTS public.v_stock_transfers_full;
CREATE VIEW public.v_stock_transfers_full AS
SELECT
  st.id,
  st.transfer_number,
  st.transfer_orders_id,
  to_ref.transfer_number AS to_number,
  st.from_location_id,
  st.to_location_id,
  fl.location_name AS from_name,
  fl.location_code AS from_code,
  tl.location_name AS to_name,
  tl.location_code AS to_code,
  st.status,
  st.created_by,
  public.fn_user_display_name(st.created_by) AS created_by_name,
  st.created_at,
  st.updated_at,
  st.business_date,
  (SELECT COALESCE(sum(sti.transfer_qty), 0::numeric) FROM stock_transfer_items sti WHERE sti.transfer_id = st.id) AS total_qty,
  (SELECT COALESCE(sum(sti.picked_qty), 0::numeric) FROM stock_transfer_items sti WHERE sti.transfer_id = st.id) AS total_picked,
  (SELECT COALESCE(sum(sti.received_qty), 0::numeric) FROM stock_transfer_items sti WHERE sti.transfer_id = st.id) AS total_received,
  (SELECT count(*) FROM stock_transfer_items sti WHERE sti.transfer_id = st.id) AS item_count
FROM stock_transfers st
LEFT JOIN transfer_orders to_ref ON to_ref.id = st.transfer_orders_id
LEFT JOIN inventory_locations fl ON fl.id = st.from_location_id
LEFT JOIN inventory_locations tl ON tl.id = st.to_location_id;

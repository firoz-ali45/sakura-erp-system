-- RPC to return PR item summary (SECURITY DEFINER so client gets DB-aggregated values regardless of RLS)
CREATE OR REPLACE FUNCTION public.fn_get_pr_item_summary(p_pr_id uuid)
RETURNS TABLE(pr_item_id uuid, ordered_po_qty numeric, received_grn_qty numeric, invoiced_pur_qty numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT v.pr_item_id, v.ordered_po_qty, v.received_grn_qty, v.invoiced_pur_qty
  FROM v_pr_item_summary v
  WHERE v.pr_id = p_pr_id;
$$;

COMMENT ON FUNCTION public.fn_get_pr_item_summary(uuid) IS 'Returns DB-aggregated ordered/received/invoiced per PR item. SECURITY DEFINER so client gets data regardless of RLS.';

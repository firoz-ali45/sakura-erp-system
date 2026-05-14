-- List inventory_items for custom app login (PostgREST role anon without JWT).
-- RLS on inventory_items is TO authenticated only; this SECURITY DEFINER RPC
-- validates the user and returns rows for their company_id.

CREATE OR REPLACE FUNCTION public.fn_app_list_inventory_items(
  p_user_id uuid,
  p_include_deleted boolean DEFAULT false
)
RETURNS SETOF public.inventory_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $fn$
DECLARE
  v_company uuid;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'missing user id' USING ERRCODE = '22023';
  END IF;

  SELECT u.company_id INTO v_company
  FROM public.users u
  WHERE u.id = p_user_id
  LIMIT 1;

  IF v_company IS NULL THEN
    RAISE EXCEPTION 'user has no company' USING ERRCODE = '28000';
  END IF;

  IF NOT public.fn_subscription_active(v_company) THEN
    RAISE EXCEPTION 'subscription inactive for company' USING ERRCODE = '28000';
  END IF;

  RETURN QUERY
  SELECT i.*
  FROM public.inventory_items i
  WHERE i.company_id = v_company
    AND (p_include_deleted OR COALESCE(i.deleted, false) = false)
  ORDER BY i.created_at DESC NULLS LAST;
END;
$fn$;

COMMENT ON FUNCTION public.fn_app_list_inventory_items(uuid, boolean) IS
  'List inventory_items for anon/custom auth; scoped by user.company_id.';

REVOKE ALL ON FUNCTION public.fn_app_list_inventory_items(uuid, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_app_list_inventory_items(uuid, boolean) TO anon, authenticated;

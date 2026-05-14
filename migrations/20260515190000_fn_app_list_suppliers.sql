-- List suppliers for custom app login (PostgREST anon without JWT).
-- RLS on suppliers is TO authenticated only; SECURITY DEFINER RPC mirrors fn_app_list_inventory_items.

CREATE OR REPLACE FUNCTION public.fn_app_list_suppliers(
  p_user_id uuid,
  p_include_deleted boolean DEFAULT false,
  p_company_id uuid DEFAULT NULL
)
RETURNS SETOF public.suppliers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $fn$
DECLARE
  v_company uuid;
BEGIN
  IF p_user_id IS NOT NULL THEN
    SELECT u.company_id INTO v_company
    FROM public.users u
    WHERE u.id = p_user_id
    LIMIT 1;

    IF v_company IS NULL AND p_company_id IS NOT NULL THEN
      v_company := p_company_id;
    END IF;
  ELSE
    IF p_company_id IS NULL THEN
      RAISE EXCEPTION 'missing user id or company id' USING ERRCODE = '22023';
    END IF;
    v_company := p_company_id;
  END IF;

  IF v_company IS NULL THEN
    RAISE EXCEPTION 'user has no company' USING ERRCODE = '28000';
  END IF;

  IF NOT public.fn_subscription_active(v_company) THEN
    RAISE EXCEPTION 'subscription inactive for company' USING ERRCODE = '28000';
  END IF;

  RETURN QUERY
  SELECT s.*
  FROM public.suppliers s
  WHERE s.company_id = v_company
    AND (p_include_deleted OR COALESCE(s.deleted, false) = false)
  ORDER BY s.name ASC NULLS LAST;
END;
$fn$;

COMMENT ON FUNCTION public.fn_app_list_suppliers(uuid, boolean, uuid) IS
  'List suppliers for anon/custom auth; prefers users.company_id, else p_company_id.';

REVOKE ALL ON FUNCTION public.fn_app_list_suppliers(uuid, boolean, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_app_list_suppliers(uuid, boolean, uuid) TO anon, authenticated;

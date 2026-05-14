-- List / fetch purchase_orders for custom anon auth (RLS is TO authenticated only).

CREATE OR REPLACE FUNCTION public.fn_app_list_purchase_orders(
  p_user_id uuid,
  p_include_deleted boolean DEFAULT true,
  p_company_id uuid DEFAULT NULL
)
RETURNS SETOF public.purchase_orders
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
  SELECT po.*
  FROM public.purchase_orders po
  WHERE po.company_id = v_company
    AND (p_include_deleted OR COALESCE(po.deleted, false) = false)
  ORDER BY po.created_at DESC NULLS LAST;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.fn_app_get_purchase_order(
  p_user_id uuid,
  p_po_id bigint,
  p_company_id uuid DEFAULT NULL
)
RETURNS SETOF public.purchase_orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $fn2$
DECLARE
  v_company uuid;
BEGIN
  IF p_po_id IS NULL THEN
    RAISE EXCEPTION 'missing po id' USING ERRCODE = '22023';
  END IF;

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
  SELECT po.*
  FROM public.purchase_orders po
  WHERE po.id = p_po_id
    AND po.company_id = v_company
  LIMIT 1;
END;
$fn2$;

COMMENT ON FUNCTION public.fn_app_list_purchase_orders(uuid, boolean, uuid) IS
  'List purchase_orders for anon/custom auth; company from user or p_company_id.';

COMMENT ON FUNCTION public.fn_app_get_purchase_order(uuid, bigint, uuid) IS
  'Get one purchase_order by id scoped to company; anon/custom auth.';

REVOKE ALL ON FUNCTION public.fn_app_list_purchase_orders(uuid, boolean, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_app_get_purchase_order(uuid, bigint, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_app_list_purchase_orders(uuid, boolean, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_app_get_purchase_order(uuid, bigint, uuid) TO anon, authenticated;

-- Insert purchase_orders under custom anon auth (RLS is TO authenticated only).
-- Sets company_id from user/context; tenant_id from companies.tenant_id (FK to tenants.id).

CREATE OR REPLACE FUNCTION public.fn_app_insert_purchase_order(
  p_user_id uuid,
  p_company_id uuid DEFAULT NULL,
  p_po_number text DEFAULT NULL,
  p_supplier_id bigint DEFAULT NULL,
  p_supplier_name text DEFAULT NULL,
  p_source_pr_id uuid DEFAULT NULL,
  p_status text DEFAULT 'pending',
  p_business_date date DEFAULT NULL,
  p_order_date timestamptz DEFAULT NULL,
  p_total_amount numeric DEFAULT 0,
  p_vat_amount numeric DEFAULT 0,
  p_notes text DEFAULT NULL,
  p_ordered_quantity numeric DEFAULT 0,
  p_remaining_quantity numeric DEFAULT 0,
  p_receiving_status text DEFAULT 'not_received'
)
RETURNS public.purchase_orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_company uuid;
  v_tenant uuid;
  v_row public.purchase_orders%ROWTYPE;
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

  SELECT c.tenant_id INTO v_tenant
  FROM public.companies c
  WHERE c.id = v_company
  LIMIT 1;

  IF v_tenant IS NULL THEN
    RAISE EXCEPTION 'company not found or missing tenant_id' USING ERRCODE = '28000';
  END IF;

  INSERT INTO public.purchase_orders (
    company_id,
    tenant_id,
    po_number,
    supplier_id,
    supplier_name,
    source_pr_id,
    status,
    business_date,
    order_date,
    total_amount,
    vat_amount,
    notes,
    ordered_quantity,
    remaining_quantity,
    receiving_status,
    deleted,
    created_at,
    updated_at,
    created_by
  ) VALUES (
    v_company,
    v_tenant,
    NULLIF(trim(COALESCE(p_po_number, '')), ''),
    p_supplier_id,
    NULLIF(trim(COALESCE(p_supplier_name, '')), ''),
    p_source_pr_id,
    COALESCE(NULLIF(trim(COALESCE(p_status, '')), ''), 'pending'),
    p_business_date,
    COALESCE(p_order_date, now()),
    COALESCE(p_total_amount, 0),
    COALESCE(p_vat_amount, 0),
    p_notes,
    COALESCE(p_ordered_quantity, 0),
    COALESCE(p_remaining_quantity, 0),
    COALESCE(NULLIF(trim(COALESCE(p_receiving_status, '')), ''), 'not_received'),
    false,
    now(),
    now(),
    CASE
      WHEN p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_user_id)
      THEN p_user_id
      ELSE NULL
    END
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$fn$;

COMMENT ON FUNCTION public.fn_app_insert_purchase_order(uuid, uuid, text, bigint, text, uuid, text, date, timestamptz, numeric, numeric, text, numeric, numeric, text) IS
  'Insert purchase_orders for anon/custom auth; company_id from context, tenant_id from companies.tenant_id.';

REVOKE ALL ON FUNCTION public.fn_app_insert_purchase_order(uuid, uuid, text, bigint, text, uuid, text, date, timestamptz, numeric, numeric, text, numeric, numeric, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_app_insert_purchase_order(uuid, uuid, text, bigint, text, uuid, text, date, timestamptz, numeric, numeric, text, numeric, numeric, text) TO anon, authenticated;

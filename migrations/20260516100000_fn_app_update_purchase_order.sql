-- Update purchase_orders for custom anon auth (RLS is TO authenticated only).

CREATE OR REPLACE FUNCTION public.fn_app_update_purchase_order(
  p_user_id uuid,
  p_po_id bigint,
  p_company_id uuid DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_supplier_id bigint DEFAULT NULL,
  p_supplier_name text DEFAULT NULL,
  p_destination text DEFAULT NULL,
  p_business_date date DEFAULT NULL,
  p_order_date timestamptz DEFAULT NULL,
  p_expected_date timestamptz DEFAULT NULL,
  p_total_amount numeric DEFAULT NULL,
  p_vat_amount numeric DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_po_number text DEFAULT NULL
)
RETURNS public.purchase_orders
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_company uuid;
  v_row public.purchase_orders%ROWTYPE;
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

  UPDATE public.purchase_orders po
  SET
    status = COALESCE(NULLIF(trim(COALESCE(p_status, '')), ''), po.status),
    supplier_id = COALESCE(p_supplier_id, po.supplier_id),
    supplier_name = COALESCE(NULLIF(trim(COALESCE(p_supplier_name, '')), ''), po.supplier_name),
    destination = COALESCE(p_destination, po.destination),
    business_date = COALESCE(p_business_date, po.business_date),
    order_date = COALESCE(p_order_date, po.order_date),
    expected_date = COALESCE(p_expected_date, po.expected_date),
    total_amount = COALESCE(p_total_amount, po.total_amount),
    vat_amount = COALESCE(p_vat_amount, po.vat_amount),
    notes = COALESCE(p_notes, po.notes),
    po_number = COALESCE(NULLIF(trim(COALESCE(p_po_number, '')), ''), po.po_number),
    updated_at = now()
  WHERE po.id = p_po_id
    AND po.company_id = v_company
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'purchase order not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN v_row;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_app_update_purchase_order(uuid, bigint, uuid, text, bigint, text, text, date, timestamptz, timestamptz, numeric, numeric, text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_app_update_purchase_order(uuid, bigint, uuid, text, bigint, text, text, date, timestamptz, timestamptz, numeric, numeric, text, text) TO anon, authenticated;

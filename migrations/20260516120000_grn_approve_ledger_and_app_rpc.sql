-- GRN approval: ledger trigger SECURITY DEFINER + company_id on ledger rows.
-- App RPCs for anon/custom auth on grn_inspections.

-- ---------- 1) Ledger trigger (bypass RLS on insert; set company_id) ----------
CREATE OR REPLACE FUNCTION public.trg_inventory_ledger_on_grn_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item RECORD;
  v_batch RECORD;
  v_location_id uuid;
  v_warehouse_text text;
  v_unit_cost numeric(18,4);
  v_po_id bigint;
  v_batch_id uuid;
  v_has_grn_batches boolean;
  v_created_by uuid;
  v_company_id uuid;
  v_tenant_id uuid;
BEGIN
  v_created_by := COALESCE(NEW.approved_by, NEW.created_by);
  IF NEW.status NOT IN ('approved', 'passed') OR (OLD.status IS NOT NULL AND OLD.status IN ('approved', 'passed')) THEN
    RETURN NEW;
  END IF;

  v_warehouse_text := COALESCE(TRIM(NEW.receiving_location), 'Main Warehouse (W01)');
  v_location_id := public.fn_resolve_storage_location_to_id(v_warehouse_text);

  IF v_location_id IS NULL THEN
    SELECT id INTO v_location_id
    FROM public.inventory_locations
    WHERE is_active = true AND location_type = 'WAREHOUSE'
      AND (allow_grn = true OR allow_grn IS NULL)
    ORDER BY created_at
    LIMIT 1;
  END IF;

  IF v_location_id IS NULL THEN
    RAISE WARNING 'inventory_ledger: No WAREHOUSE location for GRN %. Ledger not posted.', COALESCE(NEW.grn_number, NEW.id::text);
    RETURN NEW;
  END IF;

  v_po_id := NEW.purchase_order_id;
  v_company_id := NULL;
  v_tenant_id := NULL;

  IF v_po_id IS NOT NULL THEN
    SELECT po.company_id, po.tenant_id INTO v_company_id, v_tenant_id
    FROM public.purchase_orders po
    WHERE po.id = v_po_id
    LIMIT 1;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.grn_batches gb
    WHERE gb.grn_id = NEW.id AND COALESCE(gb.quantity, 0) > 0
  ) INTO v_has_grn_batches;

  IF v_has_grn_batches THEN
    FOR v_batch IN
      SELECT gb.id AS gb_id, gb.item_id, gb.quantity AS qty, gb.storage_location
      FROM public.grn_batches gb
      WHERE gb.grn_id = NEW.id AND COALESCE(gb.quantity, 0) > 0
      ORDER BY gb.created_at, gb.id
    LOOP
      v_batch_id := v_batch.gb_id;
      v_location_id := public.fn_resolve_storage_location_to_id(v_batch.storage_location);
      IF v_location_id IS NULL THEN
        v_location_id := public.fn_resolve_storage_location_to_id(v_warehouse_text);
      END IF;
      IF v_location_id IS NULL THEN
        CONTINUE;
      END IF;

      SELECT COALESCE(poi.unit_price, 0) INTO v_unit_cost
      FROM public.purchase_order_items poi
      WHERE poi.item_id = v_batch.item_id AND poi.purchase_order_id = v_po_id
      LIMIT 1;
      IF v_unit_cost IS NULL THEN v_unit_cost := 0; END IF;

      INSERT INTO public.inventory_stock_ledger (
        item_id, location_id, batch_id, qty_in, qty_out,
        unit_cost, total_cost, movement_type, reference_type, reference_id,
        created_by, company_id, tenant_id
      ) VALUES (
        v_batch.item_id, v_location_id, v_batch_id,
        v_batch.qty, 0,
        v_unit_cost, v_batch.qty * v_unit_cost,
        'GRN'::public.inventory_movement_type, 'GRN'::public.inventory_reference_type,
        NEW.id::text, v_created_by, v_company_id, v_tenant_id
      );
    END LOOP;
  ELSE
    FOR v_item IN
      SELECT gii.item_id, gii.received_quantity AS qty, COALESCE(poi.unit_price, 0) AS unit_price
      FROM public.grn_inspection_items gii
      LEFT JOIN public.purchase_order_items poi
        ON poi.item_id = gii.item_id AND poi.purchase_order_id = v_po_id
      WHERE gii.grn_inspection_id = NEW.id AND COALESCE(gii.received_quantity, 0) > 0
    LOOP
      INSERT INTO public.inventory_stock_ledger (
        item_id, location_id, batch_id, qty_in, qty_out,
        unit_cost, total_cost, movement_type, reference_type, reference_id,
        created_by, company_id, tenant_id
      ) VALUES (
        v_item.item_id, v_location_id, NULL,
        v_item.qty, 0,
        COALESCE(v_item.unit_price, 0), v_item.qty * COALESCE(v_item.unit_price, 0),
        'GRN'::public.inventory_movement_type, 'GRN'::public.inventory_reference_type,
        NEW.id::text, v_created_by, v_company_id, v_tenant_id
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- ---------- 2) Anon-friendly ledger policies (backup for direct client inserts) ----------
DROP POLICY IF EXISTS stock_ledger_insert_anon ON public.inventory_stock_ledger;
CREATE POLICY stock_ledger_insert_anon
  ON public.inventory_stock_ledger
  FOR INSERT TO anon
  WITH CHECK (true);

DROP POLICY IF EXISTS stock_ledger_select_anon ON public.inventory_stock_ledger;
CREATE POLICY stock_ledger_select_anon
  ON public.inventory_stock_ledger
  FOR SELECT TO anon
  USING (true);

GRANT SELECT, INSERT ON public.inventory_stock_ledger TO anon;

-- ---------- 3) fn_app_get_grn ----------
CREATE OR REPLACE FUNCTION public.fn_app_get_grn(
  p_user_id uuid,
  p_grn_id uuid,
  p_company_id uuid DEFAULT NULL
)
RETURNS SETOF public.grn_inspections
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $fn$
DECLARE
  v_company uuid;
BEGIN
  IF p_grn_id IS NULL THEN
    RAISE EXCEPTION 'missing grn id' USING ERRCODE = '22023';
  END IF;

  IF p_user_id IS NOT NULL THEN
    SELECT u.company_id INTO v_company FROM public.users u WHERE u.id = p_user_id LIMIT 1;
    IF v_company IS NULL AND p_company_id IS NOT NULL THEN v_company := p_company_id; END IF;
  ELSE
    IF p_company_id IS NULL THEN RAISE EXCEPTION 'missing user id or company id' USING ERRCODE = '22023'; END IF;
    v_company := p_company_id;
  END IF;

  IF v_company IS NULL THEN RAISE EXCEPTION 'user has no company' USING ERRCODE = '28000'; END IF;
  IF NOT public.fn_subscription_active(v_company) THEN RAISE EXCEPTION 'subscription inactive' USING ERRCODE = '28000'; END IF;

  RETURN QUERY
  SELECT gi.*
  FROM public.grn_inspections gi
  LEFT JOIN public.purchase_orders po ON po.id = gi.purchase_order_id
  WHERE gi.id = p_grn_id
    AND COALESCE(gi.deleted, false) = false
    AND (po.id IS NULL OR po.company_id = v_company)
  LIMIT 1;
END;
$fn$;

-- ---------- 4) fn_app_update_grn (header fields; fires ledger trigger on status) ----------
CREATE OR REPLACE FUNCTION public.fn_app_update_grn(
  p_user_id uuid,
  p_grn_id uuid,
  p_company_id uuid DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_approved_by uuid DEFAULT NULL,
  p_approval_date timestamptz DEFAULT NULL,
  p_received_by uuid DEFAULT NULL,
  p_submitted_for_approval boolean DEFAULT NULL
)
RETURNS public.grn_inspections
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_company uuid;
  v_row public.grn_inspections%ROWTYPE;
BEGIN
  IF p_grn_id IS NULL THEN RAISE EXCEPTION 'missing grn id' USING ERRCODE = '22023'; END IF;

  IF p_user_id IS NOT NULL THEN
    SELECT u.company_id INTO v_company FROM public.users u WHERE u.id = p_user_id LIMIT 1;
    IF v_company IS NULL AND p_company_id IS NOT NULL THEN v_company := p_company_id; END IF;
  ELSE
    IF p_company_id IS NULL THEN RAISE EXCEPTION 'missing user id or company id' USING ERRCODE = '22023'; END IF;
    v_company := p_company_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.grn_inspections gi
    LEFT JOIN public.purchase_orders po ON po.id = gi.purchase_order_id
    WHERE gi.id = p_grn_id AND (po.id IS NULL OR po.company_id = v_company)
  ) THEN
    RAISE EXCEPTION 'grn not found' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.grn_inspections gi
  SET
    status = COALESCE(NULLIF(trim(COALESCE(p_status, '')), ''), gi.status),
    approved_by = COALESCE(p_approved_by, gi.approved_by),
    approval_date = COALESCE(p_approval_date, gi.approval_date),
    received_by = COALESCE(p_received_by, gi.received_by),
    submitted_for_approval = COALESCE(p_submitted_for_approval, gi.submitted_for_approval),
    updated_at = now()
  WHERE gi.id = p_grn_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_app_get_grn(uuid, uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_app_update_grn(uuid, uuid, uuid, text, uuid, timestamptz, uuid, boolean) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fn_app_get_grn(uuid, uuid, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_app_update_grn(uuid, uuid, uuid, text, uuid, timestamptz, uuid, boolean) TO anon, authenticated;

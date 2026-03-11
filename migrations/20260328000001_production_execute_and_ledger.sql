-- ============================================================
-- Execute production: deduct RM (ledger OUT), create FG batches (ledger IN).
-- FG unit cost = total consumed RM cost / FG quantity.
-- ============================================================

-- 1) Generate batch number for production-origin batches (FG)
CREATE OR REPLACE FUNCTION public.fn_generate_batch_number_production(
  p_production_id uuid,
  p_item_id uuid,
  p_production_number text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_prd text;
  v_seq int;
  v_expiry_str text := to_char(CURRENT_DATE, 'YYYYMMDD');
BEGIN
  IF p_production_id IS NULL THEN
    RETURN 'BATCH-PRD-UNKNOWN-' || v_expiry_str || '-' || lpad((floor(random() * 1000))::text, 3, '0');
  END IF;
  v_prd := COALESCE(NULLIF(TRIM(p_production_number), ''), substring(p_production_id::text, 1, 8));
  v_prd := regexp_replace(v_prd, '[^A-Za-z0-9-]', '', 'g');
  PERFORM pg_advisory_xact_lock(hashtext('PRODUCTION-' || p_production_id::text || '-' || p_item_id::text));
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
  FROM public.batches
  WHERE source_doc_type = 'PRODUCTION' AND source_doc_id = p_production_id AND item_id = p_item_id;
  RETURN 'BATCH-PRD-' || v_prd || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$$;

-- 2) Trigger: set batch_number on batches when source_doc_type = PRODUCTION
CREATE OR REPLACE FUNCTION public.trg_batches_set_batch_number()
RETURNS trigger AS $$
BEGIN
  IF (NEW.batch_number IS NULL OR TRIM(COALESCE(NEW.batch_number, '')) = '')
     AND NEW.source_doc_type = 'GRN' AND NEW.source_doc_id IS NOT NULL THEN
    NEW.batch_number := public.fn_generate_batch_number_from_grn(NEW.source_doc_id, NEW.item_id, (NEW.expiry_date)::date);
  ELSIF (NEW.batch_number IS NULL OR TRIM(COALESCE(NEW.batch_number, '')) = '')
     AND NEW.source_doc_type = 'PRODUCTION' AND NEW.source_doc_id IS NOT NULL THEN
    NEW.batch_number := public.fn_generate_batch_number_production(
      NEW.source_doc_id, NEW.item_id,
      (SELECT po.production_number FROM public.production_orders po WHERE po.id = NEW.source_doc_id)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3) Execute production RPC: deduct RM (ledger OUT), create FG batches and ledger IN
CREATE OR REPLACE FUNCTION public.fn_execute_production(
  p_production_id uuid,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_po RECORD;
  v_consumption RECORD;
  v_item RECORD;
  v_batch_id uuid;
  v_unit_cost numeric;
  v_total_rm_cost numeric;
  v_location_id uuid;
  v_storage_location text;
  v_ledger_id uuid;
BEGIN
  SELECT id, production_number, branch_id, status, company_id, tenant_id
  INTO v_po
  FROM public.production_orders
  WHERE id = p_production_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Production order not found');
  END IF;
  IF v_po.status NOT IN ('draft', 'released') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Production already closed or invalid status');
  END IF;

  v_location_id := v_po.branch_id;
  SELECT branch_name INTO v_storage_location FROM public.branches WHERE id = v_po.branch_id;

  -- RM consumption: post OUT for each production_consumption row
  FOR v_consumption IN
    SELECT pc.id, pc.item_id, pc.batch_id, pc.quantity, pc.cost
    FROM public.production_consumption pc
    WHERE pc.production_id = p_production_id
  LOOP
    INSERT INTO public.inventory_stock_ledger (
      item_id, location_id, batch_id, qty_in, qty_out, unit_cost, total_cost,
      movement_type, reference_type, reference_id, created_by
    ) VALUES (
      v_consumption.item_id, v_location_id, v_consumption.batch_id,
      0, v_consumption.quantity,
      CASE WHEN v_consumption.quantity > 0 THEN v_consumption.cost / v_consumption.quantity ELSE 0 END,
      v_consumption.cost,
      'PRODUCTION_CONSUMPTION'::inventory_movement_type,
      'PRODUCTION'::inventory_reference_type,
      p_production_id::text,
      p_user_id
    );
  END LOOP;

  -- FG: for each production_item create batch, fg_batches row, ledger IN
  -- Cost: linked consumption to this item + share of unassigned (production_item_id null) by quantity_planned
  FOR v_item IN
    SELECT pi.id AS production_item_id, pi.item_id, pi.quantity_planned,
           (SELECT COALESCE(SUM(pc.cost), 0) FROM public.production_consumption pc
            WHERE pc.production_id = p_production_id AND pc.production_item_id = pi.id) AS linked_cost
    FROM public.production_items pi
    WHERE pi.production_id = p_production_id AND pi.quantity_planned > 0
  LOOP
    v_total_rm_cost := COALESCE(v_item.linked_cost, 0);
    -- Add share of unassigned consumption (production_item_id IS NULL) proportional to quantity_planned
    SELECT v_total_rm_cost + COALESCE(
      (SELECT SUM(pc.cost) FROM public.production_consumption pc WHERE pc.production_id = p_production_id AND pc.production_item_id IS NULL)
      * v_item.quantity_planned / NULLIF((SELECT SUM(pi2.quantity_planned) FROM public.production_items pi2 WHERE pi2.production_id = p_production_id), 0),
      0
    ) INTO v_total_rm_cost;
    v_unit_cost := CASE WHEN v_item.quantity_planned > 0 THEN v_total_rm_cost / v_item.quantity_planned ELSE 0 END;

    INSERT INTO public.batches (
      item_id, source_doc_type, source_doc_id, qty_received, branch_id,
      storage_location, tenant_id, company_id, created_by
    ) VALUES (
      v_item.item_id, 'PRODUCTION', p_production_id, v_item.quantity_planned, v_po.branch_id,
      v_storage_location, v_po.tenant_id, v_po.company_id, p_user_id
    )
    RETURNING id INTO v_batch_id;

    INSERT INTO public.fg_batches (production_id, production_item_id, item_id, batch_id, quantity, unit_cost, expiry_date)
    VALUES (p_production_id, v_item.production_item_id, v_item.item_id, v_batch_id, v_item.quantity_planned, v_unit_cost, NULL);

    INSERT INTO public.inventory_stock_ledger (
      item_id, location_id, batch_id, qty_in, qty_out, unit_cost, total_cost,
      movement_type, reference_type, reference_id, created_by
    ) VALUES (
      v_item.item_id, v_location_id, v_batch_id,
      v_item.quantity_planned, 0, v_unit_cost, v_total_rm_cost,
      'PRODUCTION_IN'::inventory_movement_type,
      'PRODUCTION'::inventory_reference_type,
      p_production_id::text,
      p_user_id
    );
  END LOOP;

  UPDATE public.production_items SET quantity_produced = quantity_planned WHERE production_id = p_production_id;
  UPDATE public.production_orders
  SET produced_qty = (SELECT COALESCE(SUM(quantity_planned), 0) FROM public.production_items WHERE production_id = p_production_id),
      status = 'closed',
      updated_at = now()
  WHERE id = p_production_id;

  RETURN jsonb_build_object('ok', true, 'production_id', p_production_id);
END;
$$;

COMMENT ON FUNCTION public.fn_execute_production(uuid, uuid) IS 'Execute production: post RM consumption (OUT), create FG batches and post IN; close order.';

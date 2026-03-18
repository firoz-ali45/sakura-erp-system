-- ============================================================
-- PRODUCTION: Assign production number only when user clicks Produce.
-- Until then, order shows as "Draft"; number (PRD-YYYY-NNNNNN) set on execute.
-- ============================================================

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
  v_item RECORD;
  v_recipe_id uuid;
  v_base_qty numeric;
  v_ing RECORD;
  v_required numeric;
  v_consumption RECORD;
  v_batch_id uuid;
  v_unit_cost numeric;
  v_total_rm_cost numeric;
  v_location_id uuid;
  v_storage_location text;
  v_bal RECORD;
  v_deduct numeric;
  v_ingredient_item_id uuid;
  v_ing_qty numeric;
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

  -- Assign production number only when executing (was Draft until now)
  IF v_po.production_number IS NULL OR trim(v_po.production_number) = '' OR v_po.production_number LIKE 'Draft%' THEN
    UPDATE public.production_orders
    SET production_number = public.fn_next_production_number(v_po.tenant_id)
    WHERE id = p_production_id;
    SELECT id, production_number, branch_id, status, company_id, tenant_id
    INTO v_po
    FROM public.production_orders
    WHERE id = p_production_id;
  END IF;

  v_location_id := v_po.branch_id;
  SELECT branch_name INTO v_storage_location FROM public.branches WHERE id = v_po.branch_id;

  -- ---------- 1) Auto-fill production_consumption from recipe ----------
  FOR v_item IN
    SELECT pi.id AS production_item_id, pi.item_id, pi.quantity_planned, pi.recipe_id
    FROM public.production_items pi
    WHERE pi.production_id = p_production_id AND pi.quantity_planned > 0
  LOOP
    v_recipe_id := v_item.recipe_id;
    IF v_recipe_id IS NULL THEN
      SELECT r.id INTO v_recipe_id
      FROM public.recipes r
      WHERE (r.item_id = v_item.item_id OR r.output_item_id = v_item.item_id)
        AND r.status IN ('active', 'draft')
      ORDER BY r.recipe_version DESC NULLS LAST
      LIMIT 1;
    END IF;

    IF v_recipe_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.production_consumption pc
      WHERE pc.production_id = p_production_id AND pc.production_item_id = v_item.production_item_id
    ) THEN
      SELECT COALESCE(r.base_quantity, 1) INTO v_base_qty
      FROM public.recipes r WHERE r.id = v_recipe_id;
      v_base_qty := NULLIF(v_base_qty, 0);
      IF v_base_qty IS NULL THEN v_base_qty := 1; END IF;

      FOR v_ing IN
        SELECT ri.id, COALESCE(ri.ingredient_item_id, ri.item_id) AS ingredient_item_id,
               COALESCE(ri.quantity, ri.quantity_required) AS qty_per_base
        FROM public.recipe_ingredients ri
        WHERE ri.recipe_id = v_recipe_id
      LOOP
        v_ingredient_item_id := v_ing.ingredient_item_id;
        v_ing_qty := COALESCE(v_ing.qty_per_base, 0);
        IF v_ingredient_item_id IS NULL OR v_ing_qty <= 0 THEN CONTINUE; END IF;

        v_required := (v_ing_qty / v_base_qty) * v_item.quantity_planned;
        IF v_required <= 0 THEN CONTINUE; END IF;

        FOR v_bal IN
          SELECT vb.batch_id, vb.current_qty AS cur_qty, COALESCE(vb.avg_cost, 0) AS avg_cost
          FROM public.v_inventory_balance vb
          WHERE vb.item_id = v_ingredient_item_id AND vb.location_id = v_location_id AND vb.current_qty > 0
          ORDER BY vb.batch_id
        LOOP
          EXIT WHEN v_required <= 0;
          v_deduct := LEAST(v_required, v_bal.cur_qty);
          INSERT INTO public.production_consumption (
            production_id, production_item_id, item_id, batch_id, quantity, cost, company_id, tenant_id
          ) VALUES (
            p_production_id, v_item.production_item_id, v_ingredient_item_id, v_bal.batch_id,
            v_deduct, v_deduct * v_bal.avg_cost, v_po.company_id, v_po.tenant_id
          );
          v_required := v_required - v_deduct;
        END LOOP;

        IF v_required > 0.0001 THEN
          RAISE EXCEPTION 'Insufficient stock for ingredient item % (required: %, short: %)',
            v_ingredient_item_id, (v_ing_qty / v_base_qty) * v_item.quantity_planned, v_required;
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  -- ---------- 2) RM consumption: post OUT ----------
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

  -- ---------- 3) FG: batches + ledger IN ----------
  FOR v_item IN
    SELECT pi.id AS production_item_id, pi.item_id, pi.quantity_planned,
           (SELECT COALESCE(SUM(pc.cost), 0) FROM public.production_consumption pc
            WHERE pc.production_id = p_production_id AND pc.production_item_id = pi.id) AS linked_cost
    FROM public.production_items pi
    WHERE pi.production_id = p_production_id AND pi.quantity_planned > 0
  LOOP
    v_total_rm_cost := COALESCE(v_item.linked_cost, 0);
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

  RETURN jsonb_build_object('ok', true, 'production_id', p_production_id, 'production_number', v_po.production_number);
END;
$$;

COMMENT ON FUNCTION public.fn_execute_production(uuid, uuid) IS 'Execute production: assign PRD number if Draft, auto-fill consumption from recipe, post RM OUT and FG IN, close order.';

-- Allow picking one transfer line from multiple batches (FEFO). Replaces single-batch update for that line.
CREATE OR REPLACE FUNCTION public.fn_update_stock_transfer_item_picking_multi(
  p_transfer_id uuid,
  p_item_id uuid,
  p_allocations jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_st record;
  v_alloc jsonb;
  v_tenant_id uuid;
  v_cost numeric;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;
  IF v_st.status NOT IN ('draft', 'picking') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer not in draft or picking');
  END IF;

  v_tenant_id := v_st.tenant_id;

  IF p_allocations IS NULL OR jsonb_array_length(p_allocations) = 0 THEN
    DELETE FROM stock_transfer_items WHERE transfer_id = p_transfer_id AND item_id = p_item_id;
    RETURN jsonb_build_object('ok', true);
  END IF;

  DELETE FROM stock_transfer_items WHERE transfer_id = p_transfer_id AND item_id = p_item_id;

  FOR v_alloc IN SELECT * FROM jsonb_array_elements(p_allocations)
  LOOP
    v_cost := (v_alloc->>'unit_cost')::numeric;
    IF v_cost IS NULL AND (v_alloc->>'batch_id') IS NOT NULL THEN
      SELECT COALESCE(avg_cost, 0) INTO v_cost
      FROM v_inventory_balance
      WHERE item_id = p_item_id AND location_id = v_st.from_location_id AND batch_id = (v_alloc->>'batch_id')::uuid
      LIMIT 1;
    END IF;

    INSERT INTO stock_transfer_items (
      transfer_id, item_id, batch_id, transfer_qty, picked_qty,
      damaged_qty, unit_cost, tenant_id
    ) VALUES (
      p_transfer_id,
      p_item_id,
      (v_alloc->>'batch_id')::uuid,
      GREATEST(COALESCE((v_alloc->>'picked_qty')::numeric, 0), 0),
      GREATEST(COALESCE((v_alloc->>'picked_qty')::numeric, 0), 0),
      GREATEST(COALESCE((v_alloc->>'damaged_qty')::numeric, 0), 0),
      COALESCE(v_cost, 0),
      v_tenant_id
    );
  END LOOP;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

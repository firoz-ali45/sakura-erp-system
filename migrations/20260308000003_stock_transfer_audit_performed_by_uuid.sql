-- Root cause: Start Picking / Confirm Picking / Dispatch used p_user_id text (default 'user')
-- and wrote to stock_transfer_audit.performed_by (UUID) -> "performed_by is of type uuid but expression is of type text".
-- Fix: accept p_user_id as UUID, use NULL when not provided; never pass literal text to UUID columns.

DROP FUNCTION IF EXISTS public.fn_start_picking_stock_transfer(uuid, text);
CREATE OR REPLACE FUNCTION public.fn_start_picking_stock_transfer(p_transfer_id uuid, p_user_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_st record;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;
  IF v_st.status != 'draft' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer must be in draft');
  END IF;

  UPDATE stock_transfers SET status = 'picking', updated_at = now() WHERE id = p_transfer_id;
  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'picking_started', p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

DROP FUNCTION IF EXISTS public.fn_confirm_picking_stock_transfer(uuid, text);
CREATE OR REPLACE FUNCTION public.fn_confirm_picking_stock_transfer(p_transfer_id uuid, p_user_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_st record;
  v_missing_batch int;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;

  IF v_st.status != 'picking' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer must be in picking status. Click Start Picking first.');
  END IF;

  SELECT COUNT(*) INTO v_missing_batch
  FROM stock_transfer_items
  WHERE transfer_id = p_transfer_id
    AND transfer_qty > 0
    AND (batch_id IS NULL OR COALESCE(picked_qty, 0) <= 0);
  IF v_missing_batch > 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'All items must have batch selected and picked qty before marking as Picked');
  END IF;

  UPDATE stock_transfers SET status = 'picked', updated_at = now() WHERE id = p_transfer_id;
  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'picked', p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

DROP FUNCTION IF EXISTS public.fn_dispatch_stock_transfer(uuid, text);
CREATE OR REPLACE FUNCTION public.fn_dispatch_stock_transfer(p_transfer_id uuid, p_user_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_st record;
  v_item record;
  v_avail numeric;
  v_qty numeric;
  v_missing_batch int;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;

  IF v_st.status NOT IN ('draft', 'picked') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer already dispatched or completed');
  END IF;

  SELECT COUNT(*) INTO v_missing_batch
  FROM stock_transfer_items
  WHERE transfer_id = p_transfer_id
    AND GREATEST(COALESCE(picked_qty, transfer_qty), 0) > 0
    AND batch_id IS NULL;
  IF v_missing_batch > 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Cannot dispatch: all items must have batch selected');
  END IF;

  FOR v_item IN SELECT * FROM stock_transfer_items WHERE transfer_id = p_transfer_id
  LOOP
    v_qty := GREATEST(COALESCE(v_item.picked_qty, v_item.transfer_qty), 0);
    IF v_qty <= 0 THEN CONTINUE; END IF;

    IF v_item.batch_id IS NOT NULL THEN
      SELECT COALESCE(current_qty, 0) INTO v_avail
      FROM v_inventory_balance
      WHERE item_id = v_item.item_id AND location_id = v_st.from_location_id AND batch_id = v_item.batch_id;
    ELSE
      SELECT COALESCE(SUM(current_qty), 0) INTO v_avail
      FROM v_inventory_balance
      WHERE item_id = v_item.item_id AND location_id = v_st.from_location_id;
    END IF;

    IF COALESCE(v_avail, 0) < v_qty THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Insufficient stock in source warehouse');
    END IF;
  END LOOP;

  INSERT INTO inventory_stock_ledger (
    item_id, location_id, batch_id, qty_in, qty_out, unit_cost, total_cost,
    movement_type, reference_type, reference_id, created_by
  )
  SELECT
    sti.item_id, v_st.from_location_id, sti.batch_id,
    0, GREATEST(COALESCE(sti.picked_qty, sti.transfer_qty), 0),
    COALESCE(sti.unit_cost, 0),
    COALESCE(sti.unit_cost, 0) * GREATEST(COALESCE(sti.picked_qty, sti.transfer_qty), 0),
    'TRANSFER_OUT'::inventory_movement_type, 'TRANSFER'::inventory_reference_type,
    p_transfer_id::text, p_user_id
  FROM stock_transfer_items sti
  WHERE sti.transfer_id = p_transfer_id
  AND GREATEST(COALESCE(sti.picked_qty, sti.transfer_qty), 0) > 0;

  UPDATE stock_transfers SET status = 'in_transit', updated_at = now() WHERE id = p_transfer_id;
  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'dispatched', p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

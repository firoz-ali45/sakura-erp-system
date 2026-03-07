-- created_by/performed_by/handed_over_by are UUID; p_user_id was text -> "created_by is of type uuid but expression is of type text".
-- Fix: accept p_user_id as uuid, use NULL when not provided (unified schema).
DROP FUNCTION IF EXISTS public.fn_dispatch_to_driver(uuid, uuid, text, text, timestamptz, text, text);
CREATE OR REPLACE FUNCTION public.fn_dispatch_to_driver(
  p_transfer_id uuid,
  p_driver_id uuid,
  p_vehicle_no text DEFAULT NULL,
  p_seal_number text DEFAULT NULL,
  p_expected_delivery_time timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
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
  v_driver_name text;
  v_driver_phone text;
  v_is_driver boolean;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;
  IF v_st.status NOT IN ('draft', 'picked') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer already dispatched or completed');
  END IF;

  IF p_driver_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Driver selection required');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id AND (r.deleted IS NULL OR r.deleted = false)
    WHERE ur.user_id = p_driver_id
      AND upper(r.role_code) = 'DRIVER'
  ) INTO v_is_driver;

  IF NOT v_is_driver THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Selected user must have role=driver');
  END IF;

  SELECT name, phone INTO v_driver_name, v_driver_phone FROM users WHERE id = p_driver_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Driver not found');
  END IF;

  IF EXISTS (SELECT 1 FROM users WHERE id = p_driver_id AND (status IS NULL OR lower(status) != 'active')) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Driver must have active status');
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

  INSERT INTO logistics_handover (transfer_id, handed_over_by, driver_id, vehicle_no, driver_mobile, seal_number, handover_notes, expected_delivery_time, status)
  VALUES (p_transfer_id, p_user_id, p_driver_id, p_vehicle_no, v_driver_phone, p_seal_number, p_notes, p_expected_delivery_time, 'HANDED_OVER');

  UPDATE stock_transfers SET status = 'handed_to_driver', updated_at = now() WHERE id = p_transfer_id;
  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'handed_to_driver', p_user_id);
  RETURN jsonb_build_object('ok', true, 'driver_name', v_driver_name);
END;
$function$;

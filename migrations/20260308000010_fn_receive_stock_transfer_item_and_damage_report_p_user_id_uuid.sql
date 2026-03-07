-- created_by/performed_by are UUID; p_user_id was text -> "created_by is of type uuid but expression is of type text".
-- Fix: fn_receive_stock_transfer_item and fn_insert_transfer_damage_report accept p_user_id as uuid (unified schema).
DROP FUNCTION IF EXISTS public.fn_receive_stock_transfer_item(uuid, uuid, uuid, numeric, numeric, numeric, text);
CREATE OR REPLACE FUNCTION public.fn_receive_stock_transfer_item(
  p_transfer_id uuid,
  p_item_id uuid,
  p_batch_id uuid,
  p_received_qty numeric,
  p_damaged_qty numeric,
  p_rejected_qty numeric,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_st record;
  v_item record;
  v_dispatch_qty numeric;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;
  IF v_st.status NOT IN ('in_transit', 'partially_received', 'arrived') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer not ready for receive. Status must be arrived or in transit.');
  END IF;

  SELECT * INTO v_item FROM stock_transfer_items
  WHERE transfer_id = p_transfer_id AND item_id = p_item_id
  AND (batch_id IS NOT DISTINCT FROM p_batch_id)
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT * INTO v_item FROM stock_transfer_items
    WHERE transfer_id = p_transfer_id AND item_id = p_item_id
    ORDER BY batch_id NULLS LAST LIMIT 1;
  END IF;

  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Item not found'); END IF;

  v_dispatch_qty := COALESCE(v_item.picked_qty, v_item.transfer_qty);
  IF p_received_qty + p_damaged_qty + p_rejected_qty > v_dispatch_qty THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Received + damaged + rejected cannot exceed dispatched');
  END IF;

  UPDATE stock_transfer_items SET
    received_qty = COALESCE(received_qty, 0) + p_received_qty,
    damaged_qty = COALESCE(damaged_qty, 0) + p_damaged_qty,
    rejected_qty = COALESCE(rejected_qty, 0) + p_rejected_qty,
    variance_qty = v_dispatch_qty - (COALESCE(received_qty, 0) + p_received_qty + COALESCE(damaged_qty, 0) + p_damaged_qty + COALESCE(rejected_qty, 0) + p_rejected_qty),
    updated_at = now()
  WHERE id = v_item.id;

  IF p_received_qty > 0 THEN
    INSERT INTO inventory_stock_ledger (
      item_id, location_id, batch_id, qty_in, qty_out, unit_cost, total_cost,
      movement_type, reference_type, reference_id, created_by
    ) VALUES (
      p_item_id, v_st.to_location_id, COALESCE(p_batch_id, v_item.batch_id),
      p_received_qty, 0, COALESCE(v_item.unit_cost, 0), COALESCE(v_item.unit_cost, 0) * p_received_qty,
      'TRANSFER_IN'::inventory_movement_type, 'TRANSFER'::inventory_reference_type, p_transfer_id::text, p_user_id
    );
  END IF;

  IF EXISTS (SELECT 1 FROM stock_transfer_items WHERE transfer_id = p_transfer_id AND COALESCE(received_qty, 0) < COALESCE(picked_qty, transfer_qty)) THEN
    UPDATE stock_transfers SET status = 'partially_received', updated_at = now() WHERE id = p_transfer_id;
  ELSE
    UPDATE stock_transfers SET status = 'completed', updated_at = now() WHERE id = p_transfer_id;
  END IF;

  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'received', p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

DROP FUNCTION IF EXISTS public.fn_insert_transfer_damage_report(uuid, uuid, numeric, text, text, text);
CREATE OR REPLACE FUNCTION public.fn_insert_transfer_damage_report(
  p_transfer_id uuid,
  p_item_id uuid,
  p_damaged_qty numeric,
  p_responsibility text,
  p_notes text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  IF p_damaged_qty <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Damaged qty must be positive');
  END IF;
  IF p_responsibility NOT IN ('WAREHOUSE', 'DRIVER', 'BRANCH') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Responsibility must be WAREHOUSE, DRIVER, or BRANCH');
  END IF;

  INSERT INTO transfer_damage_reports (transfer_id, item_id, damaged_qty, responsibility, notes, created_by)
  VALUES (p_transfer_id, p_item_id, p_damaged_qty, p_responsibility, p_notes, p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

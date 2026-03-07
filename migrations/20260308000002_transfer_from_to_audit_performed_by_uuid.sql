-- Root cause: fn_create_transfer_from_to inserted 'system' (text) into stock_transfer_audit.performed_by (UUID).
-- Error: invalid input syntax for type uuid: 'system'
-- Fix: use requested_by (UUID) only; when null, performed_by stays NULL (column allows NULL).
CREATE OR REPLACE FUNCTION public.fn_create_transfer_from_to(p_to_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_to record;
  v_item record;
  v_trs_num text;
  v_transfer_id uuid;
  v_seq bigint;
BEGIN
  SELECT * INTO v_to FROM transfer_orders WHERE id = p_to_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer order not found');
  END IF;

  IF v_to.status NOT IN ('level1_approved', 'level2_approved') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer order must be approved first');
  END IF;

  v_seq := nextval('transfer_number_seq');
  v_trs_num := 'TRS-' || lpad(v_seq::text, 6, '0');

  INSERT INTO stock_transfers (
    transfer_number, transfer_orders_id, from_location_id, to_location_id,
    status, created_by, business_date
  ) VALUES (
    v_trs_num, p_to_id, v_to.from_location_id, v_to.to_location_id,
    'draft', v_to.requested_by, COALESCE(v_to.business_date, CURRENT_DATE)
  )
  RETURNING id INTO v_transfer_id;

  FOR v_item IN
    SELECT toi.item_id, toi.requested_qty
    FROM transfer_order_items toi
    WHERE toi.transfer_id = p_to_id
    AND toi.requested_qty > 0
  LOOP
    INSERT INTO stock_transfer_items (transfer_id, item_id, transfer_qty)
    VALUES (v_transfer_id, v_item.item_id, v_item.requested_qty);
  END LOOP;

  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by)
  VALUES (v_transfer_id, 'created', v_to.requested_by);

  RETURN jsonb_build_object('ok', true, 'transfer_id', v_transfer_id, 'transfer_number', v_trs_num);
END;
$function$;

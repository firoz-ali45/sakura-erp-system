-- performed_by is UUID; p_user_id was text -> "performed_by is of type uuid but expression is of type text".
-- Fix: accept p_user_id as uuid for both Mark In Transit and Mark Arrived (unified schema).
DROP FUNCTION IF EXISTS public.fn_warehouse_mark_in_transit(uuid, text);
CREATE OR REPLACE FUNCTION public.fn_warehouse_mark_in_transit(p_transfer_id uuid, p_user_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_st record;
  v_ho record;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;
  IF v_st.status != 'handed_to_driver' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer must be handed to driver first');
  END IF;

  SELECT * INTO v_ho FROM logistics_handover WHERE transfer_id = p_transfer_id ORDER BY handover_time DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'No handover record'); END IF;

  UPDATE logistics_handover SET status = 'IN_TRANSIT', driver_accepted_at = now(), updated_at = now() WHERE id = v_ho.id;
  UPDATE stock_transfers SET status = 'in_transit', updated_at = now() WHERE id = p_transfer_id;
  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'marked_in_transit', p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

DROP FUNCTION IF EXISTS public.fn_warehouse_mark_arrived(uuid, text);
CREATE OR REPLACE FUNCTION public.fn_warehouse_mark_arrived(p_transfer_id uuid, p_user_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_st record;
  v_ho record;
BEGIN
  SELECT * INTO v_st FROM stock_transfers WHERE id = p_transfer_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found'); END IF;
  IF v_st.status != 'in_transit' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer must be in transit first');
  END IF;

  SELECT * INTO v_ho FROM logistics_handover WHERE transfer_id = p_transfer_id ORDER BY handover_time DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'No handover record'); END IF;

  UPDATE logistics_handover SET status = 'ARRIVED', arrived_at = now(), updated_at = now() WHERE id = v_ho.id;
  UPDATE stock_transfers SET status = 'arrived', updated_at = now() WHERE id = p_transfer_id;
  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'arrived', p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

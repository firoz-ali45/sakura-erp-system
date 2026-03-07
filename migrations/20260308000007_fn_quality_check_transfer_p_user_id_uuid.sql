-- checked_by and performed_by are UUID; p_user_id was text -> "checked by is of type uuid but expression is of type text".
-- Fix: accept p_user_id as uuid (unified schema).
DROP FUNCTION IF EXISTS public.fn_quality_check_transfer(uuid, text, numeric, boolean, boolean, text, text);
CREATE OR REPLACE FUNCTION public.fn_quality_check_transfer(
  p_transfer_id uuid,
  p_condition_status text,
  p_temperature numeric DEFAULT NULL,
  p_damage_flag boolean DEFAULT false,
  p_expired_items_flag boolean DEFAULT false,
  p_notes text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM stock_transfers WHERE id = p_transfer_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found');
  END IF;
  IF p_condition_status NOT IN ('GOOD', 'DAMAGED', 'WET') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid condition status');
  END IF;

  INSERT INTO transfer_quality_checks (transfer_id, checked_by, condition_status, temperature, damage_flag, expired_items_flag, notes)
  VALUES (p_transfer_id, p_user_id, p_condition_status, p_temperature, p_damage_flag, p_expired_items_flag, p_notes);

  INSERT INTO stock_transfer_audit (transfer_id, action, performed_by) VALUES (p_transfer_id, 'quality_checked', p_user_id);
  RETURN jsonb_build_object('ok', true);
END;
$function$;

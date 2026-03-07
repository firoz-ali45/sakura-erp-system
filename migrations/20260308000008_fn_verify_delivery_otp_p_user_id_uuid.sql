-- verified_by is UUID; p_user_id was text -> "verified_by is of type uuid but expression is of type text".
DROP FUNCTION IF EXISTS public.fn_verify_delivery_otp(uuid, text, text);
CREATE OR REPLACE FUNCTION public.fn_verify_delivery_otp(p_transfer_id uuid, p_otp text, p_user_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_rec record;
BEGIN
  SELECT * INTO v_rec FROM delivery_otp_logs
  WHERE transfer_id = p_transfer_id AND verified_at IS NULL
  ORDER BY generated_at DESC LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No pending OTP for this transfer');
  END IF;
  IF v_rec.otp_code != p_otp THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid OTP');
  END IF;
  IF v_rec.expires_at IS NOT NULL AND now() > v_rec.expires_at THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OTP expired');
  END IF;

  UPDATE delivery_otp_logs SET verified_at = now(), verified_by = p_user_id WHERE id = v_rec.id;
  RETURN jsonb_build_object('ok', true);
END;
$function$;

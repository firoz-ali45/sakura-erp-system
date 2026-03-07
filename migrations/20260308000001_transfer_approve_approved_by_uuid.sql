-- Root cause: fn_approve_transfer_level had p_approved_by as TEXT but writes to UUID columns
-- (transfer_approvals.approved_by, transfer_orders.approved_by_level1/approved_by_level2).
-- PostgreSQL error: "column approved_by is of type uuid but expression is of type text".
-- Fix: accept p_approved_by as UUID and use it directly (no text->uuid assignment).
-- Also drop old TEXT overloads to avoid "Could not choose the best candidate function" ambiguity.
DROP FUNCTION IF EXISTS public.fn_approve_transfer_level(uuid, integer, text);
DROP FUNCTION IF EXISTS public.fn_reject_transfer(uuid, text);

CREATE OR REPLACE FUNCTION public.fn_approve_transfer_level(
  p_transfer_id uuid,
  p_level integer,
  p_approved_by uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_required int;
  v_current int;
  v_status text;
BEGIN
  IF p_approved_by IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Approver (approved_by) is required');
  END IF;

  SELECT approval_level_required, current_approval_level, status::text
  INTO v_required, v_current, v_status
  FROM transfer_orders WHERE id = p_transfer_id;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found');
  END IF;

  IF v_status = 'rejected' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer was rejected');
  END IF;

  IF p_level != v_current + 1 OR p_level > v_required THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Invalid approval level. Expected: ' || (v_current + 1));
  END IF;

  INSERT INTO transfer_approvals (transfer_id, approval_level, approved_by, approved_at, status)
  VALUES (p_transfer_id, p_level, p_approved_by, now(), 'approved')
  ON CONFLICT (transfer_id, approval_level) DO UPDATE
  SET approved_by = EXCLUDED.approved_by, approved_at = EXCLUDED.approved_at, status = 'approved', updated_at = now();

  UPDATE transfer_orders
  SET current_approval_level = p_level,
      approved_by_level1 = CASE WHEN p_level = 1 THEN p_approved_by ELSE approved_by_level1 END,
      approved_by_level2 = CASE WHEN p_level = 2 THEN p_approved_by ELSE approved_by_level2 END,
      status = CASE
        WHEN p_level = 1 THEN 'level1_approved'::transfer_order_status
        WHEN p_level = 2 THEN 'level2_approved'::transfer_order_status
        ELSE status
      END,
      updated_at = now()
  WHERE id = p_transfer_id;

  RETURN jsonb_build_object('ok', true, 'level', p_level);
END;
$function$;

-- Same root cause: fn_reject_transfer had p_rejected_by as TEXT but transfer_orders.rejected_by is UUID.
CREATE OR REPLACE FUNCTION public.fn_reject_transfer(
  p_transfer_id uuid,
  p_rejected_by uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE transfer_orders
  SET status = 'rejected',
      rejected_by = p_rejected_by,
      updated_at = now()
  WHERE id = p_transfer_id AND status IN ('submitted','level1_approved');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transfer not found or cannot be rejected');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

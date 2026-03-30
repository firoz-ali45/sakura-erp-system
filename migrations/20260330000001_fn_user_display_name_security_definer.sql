-- Views (v_stock_transfers_full, v_transfer_orders_full, etc.) call fn_user_display_name(created_by).
-- Under SaaS RLS, SELECT on public.users is only self-row; subquery in plain STABLE function runs as invoker → no row → "Not available".
-- SECURITY DEFINER + fixed search_path: resolve display names for any user id (same trust model as fn_list_company_users).

CREATE OR REPLACE FUNCTION public.fn_user_display_name(p_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT COALESCE(NULLIF(TRIM(u.name), ''), SPLIT_PART(u.email, '@', 1))
     FROM public.users u
     WHERE u.id = p_user_id
     LIMIT 1),
    'Not available'
  );
$$;

COMMENT ON FUNCTION public.fn_user_display_name(uuid) IS
  'User full name or email local-part for UI; bypasses users RLS for read-only display.';

-- User Management list: anon cannot SELECT public.users under SaaS RLS.
-- Return all users for one company (no password_hash) for the custom-auth SPA.

CREATE OR REPLACE FUNCTION public.fn_list_company_users(p_company_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', u.id,
        'name', u.name,
        'email', u.email,
        'phone', u.phone,
        'role', u.role,
        'status', u.status,
        'profile_photo_url', u.profile_photo_url,
        'permissions', u.permissions,
        'notes', u.notes,
        'company_id', u.company_id,
        'created_at', u.created_at,
        'updated_at', u.updated_at,
        'last_login', u.last_login,
        'last_activity', u.last_activity
      )
      ORDER BY u.created_at DESC NULLS LAST
    ),
    '[]'::jsonb
  )
  FROM public.users u
  WHERE u.company_id = p_company_id;
$$;

COMMENT ON FUNCTION public.fn_list_company_users(uuid) IS
  'List users for a company (bypasses RLS). Used by SPA with company context in localStorage.';

GRANT EXECUTE ON FUNCTION public.fn_list_company_users(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_list_company_users(uuid) TO authenticated;

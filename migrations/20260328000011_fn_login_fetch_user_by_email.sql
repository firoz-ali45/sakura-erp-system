-- Login needs to read one user row by email before any Supabase Auth JWT exists.
-- RLS on public.users only allows authenticated (self / company admin), so anon
-- direct SELECT fails (PGRST116 / misleading "network" errors in the app).
-- This RPC runs as definer and returns only fields required for custom password login.

CREATE OR REPLACE FUNCTION public.fn_login_fetch_user_by_email(p_email text)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'password_hash', u.password_hash,
    'status', u.status,
    'role', u.role,
    'name', u.name,
    'permissions', u.permissions,
    'profile_photo_url', u.profile_photo_url,
    'phone', u.phone,
    'company_id', u.company_id,
    'created_at', u.created_at,
    'updated_at', u.updated_at,
    'last_login', u.last_login,
    'last_activity', u.last_activity
  )
  FROM public.users u
  WHERE lower(trim(COALESCE(u.email, ''))) = lower(trim(COALESCE(p_email, '')))
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_login_fetch_user_by_email(text) IS
  'Pre-auth login: fetch one user by email for custom password check (bypasses RLS).';

GRANT EXECUTE ON FUNCTION public.fn_login_fetch_user_by_email(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_login_fetch_user_by_email(text) TO authenticated;

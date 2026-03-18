-- ============================================================
-- NEXORA ERP (SaaS) — RBAC for users table (company-scoped).
-- - Admin/Manager can read all users in their company
-- - Admin can create/update/delete users in their company
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow Admin/Manager to list users within their company
DROP POLICY IF EXISTS users_select_company_admin ON public.users;
CREATE POLICY users_select_company_admin
  ON public.users
  FOR SELECT
  TO authenticated
  USING (
    company_id = public.fn_current_company_id()
    AND EXISTS (
      SELECT 1
      FROM public.users me
      WHERE me.id = auth.uid()
        AND me.company_id = public.fn_current_company_id()
        AND lower(COALESCE(me.role, '')) IN ('admin','manager')
    )
  );

-- Admin can insert users into their company
DROP POLICY IF EXISTS users_insert_company_admin ON public.users;
CREATE POLICY users_insert_company_admin
  ON public.users
  FOR INSERT
  TO authenticated
  WITH CHECK (
    company_id = public.fn_current_company_id()
    AND EXISTS (
      SELECT 1
      FROM public.users me
      WHERE me.id = auth.uid()
        AND me.company_id = public.fn_current_company_id()
        AND lower(COALESCE(me.role, '')) = 'admin'
    )
  );

-- Admin can update users in their company
DROP POLICY IF EXISTS users_update_company_admin ON public.users;
CREATE POLICY users_update_company_admin
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (
    company_id = public.fn_current_company_id()
    AND EXISTS (
      SELECT 1
      FROM public.users me
      WHERE me.id = auth.uid()
        AND me.company_id = public.fn_current_company_id()
        AND lower(COALESCE(me.role, '')) = 'admin'
    )
  )
  WITH CHECK (
    company_id = public.fn_current_company_id()
    AND EXISTS (
      SELECT 1
      FROM public.users me
      WHERE me.id = auth.uid()
        AND me.company_id = public.fn_current_company_id()
        AND lower(COALESCE(me.role, '')) = 'admin'
    )
  );

-- Admin can delete users in their company
DROP POLICY IF EXISTS users_delete_company_admin ON public.users;
CREATE POLICY users_delete_company_admin
  ON public.users
  FOR DELETE
  TO authenticated
  USING (
    company_id = public.fn_current_company_id()
    AND EXISTS (
      SELECT 1
      FROM public.users me
      WHERE me.id = auth.uid()
        AND me.company_id = public.fn_current_company_id()
        AND lower(COALESCE(me.role, '')) = 'admin'
    )
  );


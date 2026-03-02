-- Ensure default company exists so batches.company_id_fkey (and other FKs to companies) accept fallback UUID
-- Frontend getCurrentCompanyId() uses 00000000-0000-0000-0000-000000000000 when no sakura_company_id set.
INSERT INTO public.companies (
  id,
  tenant_id,
  company_code,
  company_name,
  is_active,
  is_deleted,
  version,
  created_at,
  updated_at
)
SELECT
  '00000000-0000-0000-0000-000000000000'::uuid,
  t.id,
  'DEFAULT',
  'Default Company',
  true,
  false,
  1,
  now(),
  now()
FROM (SELECT id FROM public.tenants LIMIT 1) t
WHERE NOT EXISTS (SELECT 1 FROM public.companies WHERE id = '00000000-0000-0000-0000-000000000000');

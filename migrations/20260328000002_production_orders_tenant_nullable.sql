-- Allow production_orders.tenant_id to be NULL when no tenant context (fixes tenant_id_fkey on insert)
-- Keeps uniqueness: (tenant_id, production_number) when tenant set; single scope when tenant_id IS NULL.

ALTER TABLE public.production_orders
  ALTER COLUMN tenant_id DROP NOT NULL;

DROP INDEX IF EXISTS public.idx_production_orders_number_tenant;

CREATE UNIQUE INDEX idx_production_orders_number_tenant
  ON public.production_orders(tenant_id, production_number)
  WHERE tenant_id IS NOT NULL;

CREATE UNIQUE INDEX idx_production_orders_number_no_tenant
  ON public.production_orders(production_number)
  WHERE tenant_id IS NULL;

COMMENT ON COLUMN public.production_orders.tenant_id IS 'Optional tenant; null when no tenant context (e.g. single-company mode).';

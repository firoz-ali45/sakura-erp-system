-- SYSTEM ARCHITECTURE ALIGNMENT: company_id for multi-tenant
-- 1) Add company_id to public.batches if missing; backfill; set NOT NULL.
-- 2) Recreate grn_batches view to expose company_id (fixes schema cache "Could not find company_id column of grn_batches").
-- No wrapper logic disabled; batches (and view) accept company_id for RLS/consistency.

-- Default company UUID for backfill when no company context exists
DO $$
DECLARE
  v_default_company_id uuid := '00000000-0000-0000-0000-000000000000';
  v_has_column boolean;
BEGIN
  -- 1) Add company_id to batches if missing
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'batches' AND column_name = 'company_id'
  ) INTO v_has_column;

  IF NOT v_has_column THEN
    ALTER TABLE public.batches ADD COLUMN company_id uuid;
    RAISE NOTICE 'Added company_id to public.batches';
  END IF;
END $$;

-- 2) Backfill existing rows (use default company UUID)
UPDATE public.batches
SET company_id = COALESCE(company_id, '00000000-0000-0000-0000-000000000000'::uuid)
WHERE company_id IS NULL;

-- 3) Set NOT NULL after backfill
ALTER TABLE public.batches
  ALTER COLUMN company_id SET DEFAULT '00000000-0000-0000-0000-000000000000'::uuid;

DO $$
BEGIN
  ALTER TABLE public.batches ALTER COLUMN company_id SET NOT NULL;
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'company_id NOT NULL skipped (may already be NOT NULL or has nulls): %', SQLERRM;
END $$;

-- 4) Recreate grn_batches view to include company_id (schema cache alignment)
DROP VIEW IF EXISTS public.v_grn_batches_with_batch_number CASCADE;
DROP VIEW IF EXISTS public.grn_batches CASCADE;

CREATE VIEW public.grn_batches AS
SELECT
  b.id,
  b.source_doc_id AS grn_id,
  b.item_id,
  b.batch_number,
  b.batch_id,
  b.qty_received AS quantity,
  b.expiry_date::timestamptz AS expiry_date,
  b.qc_status,
  b.storage_location,
  b.vendor_batch_number,
  COALESCE(b.created_by::text, '') AS created_by,
  b.created_at,
  b.tenant_id,
  b.company_id
FROM public.batches b
WHERE b.source_doc_type = 'GRN' AND (b.is_deleted = false OR b.is_deleted IS NULL);

CREATE VIEW public.v_grn_batches_with_batch_number AS
SELECT
  gb.id,
  gb.grn_id,
  gb.item_id,
  COALESCE(gb.batch_number, '') AS batch_number,
  gb.batch_id,
  gb.quantity,
  gb.expiry_date,
  gb.qc_status,
  gb.storage_location,
  gb.vendor_batch_number,
  gb.created_by,
  gb.created_at,
  gb.company_id,
  gb.tenant_id
FROM public.grn_batches gb;

GRANT SELECT ON public.grn_batches TO authenticated, anon;
GRANT SELECT ON public.v_grn_batches_with_batch_number TO authenticated, anon;

-- 5) RLS: optional — if batches has RLS enabled and you use app.current_company_id, add:
--    CREATE POLICY batches_company_isolation ON public.batches
--      FOR ALL USING (company_id = current_setting('app.current_company_id', true)::uuid OR current_setting('app.current_company_id', true) IS NULL);

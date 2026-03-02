-- ============================================================
-- Schema alignment: company_id for multi-tenant
-- Fix: "Could not find the 'company_id' column of 'grn_batches' in the schema cache"
--
-- Apply: Supabase Dashboard → SQL Editor → paste and run (or supabase db push).
-- After running, reload PostgREST schema cache if needed (Supabase usually does this).
--
-- 1. Add company_id to batches if missing; backfill; NOT NULL
-- 2. Recreate grn_batches view to expose company_id (from batches)
-- 3. Recreate v_grn_batches_with_batch_number to include company_id
-- 4. RLS on batches (optional; only if no policies exist)
-- ============================================================

-- ---------- 1) batches: add company_id, backfill, NOT NULL ----------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'batches' AND column_name = 'company_id'
  ) THEN
    ALTER TABLE public.batches ADD COLUMN company_id uuid;
    RAISE NOTICE 'Added company_id to public.batches';
  END IF;
END $$;

-- Backfill: use tenant_id as company_id (same tenant context), or default
UPDATE public.batches
SET company_id = COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid)
WHERE company_id IS NULL;

ALTER TABLE public.batches ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.batches ALTER COLUMN company_id SET DEFAULT '00000000-0000-0000-0000-000000000000'::uuid;

-- ---------- 2) Recreate grn_batches view to EXPOSE company_id (schema cache) ----------
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

COMMENT ON VIEW public.grn_batches IS 'GRN batches view over batches; exposes company_id for multi-tenant schema cache';

-- ---------- 3) Recreate v_grn_batches_with_batch_number (include company_id) ----------
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
  gb.company_id
FROM public.grn_batches gb;

GRANT SELECT ON public.grn_batches TO authenticated, anon;
GRANT SELECT ON public.v_grn_batches_with_batch_number TO authenticated, anon;

-- ---------- 4) RLS: ensure batches has row-level security (optional; skip if already configured) ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'batches' AND schemaname = 'public') THEN
    ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;
    CREATE POLICY batches_allow_authenticated ON public.batches FOR ALL TO authenticated USING (true) WITH CHECK (true);
    CREATE POLICY batches_allow_anon ON public.batches FOR ALL TO anon USING (true) WITH CHECK (true);
    RAISE NOTICE 'RLS enabled on batches (company_id available for future policy filtering)';
  ELSE
    RAISE NOTICE 'batches already has RLS policies; company_id column added for multi-tenant use';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'RLS on batches: %', SQLERRM;
END $$;

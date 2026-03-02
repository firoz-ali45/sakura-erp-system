-- ============================================================
-- batches.branch_id NOT NULL — backfill + expose in grn_batches view
-- Fix: "null value in column branch_id of relation batches violates not-null constraint"
-- Applied via Supabase MCP on connected project; keep in repo for other envs.
-- ============================================================

-- Backfill branch_id for existing batches (use first active branch)
UPDATE public.batches b
SET branch_id = (SELECT id FROM public.branches WHERE (is_deleted = false OR is_deleted IS NULL) ORDER BY created_at LIMIT 1)
WHERE b.branch_id IS NULL;

-- Expose branch_id in grn_batches view (schema cache so API accepts branch_id on insert)
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
  b.company_id,
  b.branch_id
FROM public.batches b
WHERE b.source_doc_type = 'GRN' AND (b.is_deleted = false OR b.is_deleted IS NULL);

CREATE VIEW public.v_grn_batches_with_batch_number AS
SELECT
  gb.id, gb.grn_id, gb.item_id, COALESCE(gb.batch_number, '') AS batch_number, gb.batch_id,
  gb.quantity, gb.expiry_date, gb.qc_status, gb.storage_location, gb.vendor_batch_number,
  gb.created_by, gb.created_at, gb.company_id, gb.branch_id
FROM public.grn_batches gb;

GRANT SELECT ON public.grn_batches TO authenticated, anon;
GRANT SELECT ON public.v_grn_batches_with_batch_number TO authenticated, anon;

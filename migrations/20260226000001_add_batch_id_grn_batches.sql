-- Fix: column gb.batch_id does not exist — GRN approval trigger expects it
-- batches table + grn_batches view (production schema)

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='batches' AND column_name='batch_id') THEN
    ALTER TABLE public.batches ADD COLUMN batch_id text;
  END IF;
END $$;

DROP VIEW IF EXISTS public.grn_batches CASCADE;
CREATE VIEW public.grn_batches AS
SELECT
  id,
  source_doc_id AS grn_id,
  item_id,
  batch_number,
  batch_id,
  qty_received AS quantity,
  expiry_date::timestamptz AS expiry_date,
  qc_status,
  storage_location,
  vendor_batch_number,
  COALESCE(created_by::text, '') AS created_by,
  created_at,
  tenant_id
FROM public.batches b
WHERE source_doc_type = 'GRN' AND (is_deleted = false OR is_deleted IS NULL);

DROP VIEW IF EXISTS public.v_grn_batches_with_batch_number CASCADE;
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
  gb.created_at
FROM public.grn_batches gb;

GRANT SELECT ON public.grn_batches TO authenticated, anon;
GRANT SELECT ON public.v_grn_batches_with_batch_number TO authenticated, anon;

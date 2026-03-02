-- Batches tab: show created_by_name from DB so "Created By" is never "Not available"
-- Add created_by_name to v_grn_batches_with_batch_number using fn_user_display_name

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
  gb.created_at,
  gb.company_id,
  gb.branch_id,
  public.fn_user_display_name(NULLIF(TRIM(gb.created_by), '')::uuid) AS created_by_name
FROM public.grn_batches gb;

COMMENT ON VIEW public.v_grn_batches_with_batch_number IS 'GRN batches with batch_number and created_by_name for UI';

GRANT SELECT ON public.v_grn_batches_with_batch_number TO authenticated, anon;

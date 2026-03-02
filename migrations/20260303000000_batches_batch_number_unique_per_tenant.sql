-- Fix uq_batch_tenant duplicate: generate batch_number unique per (tenant_id, grn, item)
-- Previously count was per (grn_id, item_id) only; same tenant could get duplicate seq under race/retry.
-- Now count includes tenant_id so (tenant_id, batch_number) stays unique.

CREATE OR REPLACE FUNCTION public.fn_generate_batch_number_from_grn(
  p_grn_id uuid,
  p_item_id uuid DEFAULT NULL::uuid,
  p_expiry_date date DEFAULT NULL::date,
  p_tenant_id uuid DEFAULT NULL::uuid
)
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE
  v_grn_number text;
  v_seq        integer;
  v_key_id     uuid;
  v_expiry_str text;
BEGIN
  IF p_grn_id IS NULL THEN
    RETURN 'BATCH-UNKNOWN-' || to_char(COALESCE(p_expiry_date, CURRENT_DATE), 'YYYYMMDD') || '-' || lpad((floor(random() * 1000))::text, 3, '0');
  END IF;

  v_key_id := COALESCE(p_item_id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_expiry_str := to_char(COALESCE(p_expiry_date, CURRENT_DATE), 'YYYYMMDD');

  SELECT COALESCE(NULLIF(TRIM(gi.grn_number), ''), 'GRN')
    INTO v_grn_number
  FROM public.grn_inspections gi
  WHERE gi.id = p_grn_id;
  v_grn_number := regexp_replace(COALESCE(v_grn_number, 'GRN'), '[^A-Za-z0-9-]', '', 'g');
  v_grn_number := COALESCE(NULLIF(v_grn_number, ''), 'GRN');

  PERFORM pg_advisory_xact_lock(hashtext(COALESCE(p_tenant_id::text, '') || '-' || p_grn_id::text || '-' || v_key_id::text));
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
  FROM public.batches
  WHERE source_doc_type = 'GRN'
    AND source_doc_id = p_grn_id
    AND item_id = v_key_id
    AND (p_tenant_id IS NULL AND tenant_id IS NULL OR tenant_id = p_tenant_id);

  RETURN 'BATCH-' || v_grn_number || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_batches_set_batch_number()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF (NEW.batch_number IS NULL OR TRIM(COALESCE(NEW.batch_number, '')) = '')
     AND NEW.source_doc_type = 'GRN' AND NEW.source_doc_id IS NOT NULL THEN
    NEW.batch_number := public.fn_generate_batch_number_from_grn(
      NEW.source_doc_id,
      NEW.item_id,
      (NEW.expiry_date)::date,
      NEW.tenant_id
    );
  END IF;
  RETURN NEW;
END;
$function$;

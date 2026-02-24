-- UNIFIED BATCH ID — Production schema (grn_batches only, no inventory_batches link)
-- Format: BATCH-GRN-{GRN_NUMBER}-{YYYYMMDD}-{SEQ}
-- Run in Supabase SQL Editor

-- 1) fn_generate_batch_number_from_grn
CREATE OR REPLACE FUNCTION public.fn_generate_batch_number_from_grn(p_grn_id uuid, p_item_id uuid DEFAULT NULL, p_expiry_date date DEFAULT NULL)
RETURNS text AS $$
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

  PERFORM pg_advisory_xact_lock(hashtext(p_grn_id::text || '-' || v_key_id::text));
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
  FROM public._deprecated_grn_batches
  WHERE grn_id = p_grn_id AND item_id = v_key_id;

  RETURN 'BATCH-' || v_grn_number || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- 2) Trigger on _deprecated_grn_batches (base table): set batch_number when empty
CREATE OR REPLACE FUNCTION public.trg_grn_batches_set_batch_number()
RETURNS trigger AS $$
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(COALESCE(NEW.batch_number, '')) = '' THEN
    NEW.batch_number := public.fn_generate_batch_number_from_grn(NEW.grn_id, NEW.item_id, NEW.expiry_date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_grn_batches_set_batch_number ON public._deprecated_grn_batches;
CREATE TRIGGER trg_grn_batches_set_batch_number
  BEFORE INSERT ON public._deprecated_grn_batches
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_grn_batches_set_batch_number();

-- 3) v_grn_batches_with_batch_number — use gb.batch_number, storage_location, vendor_batch_number (from _deprecated_grn_batches)
DROP VIEW IF EXISTS public.v_grn_all_batches CASCADE;
DROP VIEW IF EXISTS public.v_grn_batches_with_batch_number CASCADE;

CREATE OR REPLACE VIEW public.v_grn_batches_with_batch_number AS
SELECT
  gb.id,
  gb.grn_id,
  gb.item_id,
  gb.batch_id,
  COALESCE(
    (SELECT ib.batch_number FROM public._deprecated_inventory_batches ib
     WHERE (gb.batch_id IS NOT NULL AND gb.batch_id != '' AND ib.id::text = gb.batch_id)
        OR ((gb.batch_id IS NULL OR gb.batch_id = '') AND ib.received_from_grn_id = gb.grn_id
            AND ib.item_id = gb.item_id AND ((ib.expiry_date = gb.expiry_date::date) OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)))
     ORDER BY ib.created_at, ib.id LIMIT 1),
    gb.batch_number
  ) AS batch_number,
  gb.expiry_date,
  gb.quantity,
  gb.quantity AS batch_quantity,
  gb.storage_location,
  gb.vendor_batch_number,
  COALESCE(gb.qc_status, gb.qc_data->>'qcStatus', gb.qc_data->>'qc_status', 'pending') AS qc_status,
  gb.qc_data,
  gb.created_at,
  gb.created_by
FROM public._deprecated_grn_batches gb;

CREATE OR REPLACE VIEW public.v_grn_all_batches AS
SELECT * FROM public.v_grn_batches_with_batch_number;

GRANT SELECT ON public.v_grn_batches_with_batch_number TO authenticated, anon;
GRANT SELECT ON public.v_grn_all_batches TO authenticated, anon;

-- 4) Backfill: set batch_number for existing _deprecated_grn_batches with empty batch_number
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT id, grn_id, item_id, expiry_date FROM public._deprecated_grn_batches
    WHERE batch_number IS NULL OR TRIM(batch_number) = ''
    ORDER BY grn_id, item_id, created_at, id
  LOOP
    UPDATE public._deprecated_grn_batches
    SET batch_number = public.fn_generate_batch_number_from_grn(r.grn_id, r.item_id, r.expiry_date)
    WHERE id = r.id;
  END LOOP;
END$$;

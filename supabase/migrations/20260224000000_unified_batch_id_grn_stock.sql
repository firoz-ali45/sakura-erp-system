-- ============================================================
-- UNIFIED BATCH ID: BATCH-GRN-{GRN_NUMBER}-{YYYYMMDD}-{SEQ}
-- Same format in GRN Batch Control, Stock Overview, Reports.
-- Single source: inventory_batches.batch_number
--
-- Run: Supabase Dashboard → SQL Editor, paste and run
-- OR: supabase db push (if migrations linked)
-- ============================================================

-- 1) fn_generate_batch_number_from_grn — Format: BATCH-GRN-000065-20260207-001
CREATE OR REPLACE FUNCTION fn_generate_batch_number_from_grn(p_grn_id uuid, p_item_id uuid DEFAULT NULL, p_expiry_date date DEFAULT NULL)
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
  FROM grn_inspections gi
  WHERE gi.id = p_grn_id;
  v_grn_number := regexp_replace(COALESCE(v_grn_number, 'GRN'), '[^A-Za-z0-9-]', '', 'g');
  v_grn_number := COALESCE(NULLIF(v_grn_number, ''), 'GRN');

  PERFORM pg_advisory_xact_lock(hashtext(p_grn_id::text || '-' || v_key_id::text));
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
  FROM inventory_batches
  WHERE received_from_grn_id = p_grn_id AND item_id = v_key_id;

  RETURN 'BATCH-' || v_grn_number || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- 2) trg_set_batch_number_from_grn — BEFORE INSERT on inventory_batches
CREATE OR REPLACE FUNCTION trg_set_batch_number_from_grn()
RETURNS trigger AS $$
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(COALESCE(NEW.batch_number, '')) = '' THEN
    NEW.batch_number := fn_generate_batch_number_from_grn(NEW.received_from_grn_id, NEW.item_id, NEW.expiry_date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_batch_number_from_grn ON inventory_batches;
CREATE TRIGGER trg_set_batch_number_from_grn
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_set_batch_number_from_grn();

-- 3) trg_sync_grn_batches_after_inv_batch — AFTER INSERT: link grn_batches to inventory_batches
CREATE OR REPLACE FUNCTION trg_sync_grn_batches_after_inv_batch()
RETURNS trigger AS $$
BEGIN
  UPDATE grn_batches
  SET batch_number = COALESCE(NULLIF(TRIM(grn_batches.batch_number), ''), NEW.batch_number),
      batch_id = COALESCE(NULLIF(TRIM(grn_batches.batch_id), ''), NEW.id::text),
      updated_at = NOW()
  WHERE grn_id = NEW.received_from_grn_id
    AND item_id = NEW.item_id
    AND (expiry_date::date IS NOT DISTINCT FROM (NEW.expiry_date)::date
         OR (expiry_date IS NULL AND NEW.expiry_date IS NULL));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_grn_batches_after_inv_batch ON inventory_batches;
CREATE TRIGGER trg_sync_grn_batches_after_inv_batch
  AFTER INSERT ON inventory_batches
  FOR EACH ROW
  WHEN (NEW.received_from_grn_id IS NOT NULL)
  EXECUTE FUNCTION trg_sync_grn_batches_after_inv_batch();

-- 4) Ensure grn_batches has batch_id column
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'grn_batches' AND column_name = 'batch_id') THEN
    ALTER TABLE grn_batches ADD COLUMN batch_id text;
  END IF;
END$$;

-- 5) v_grn_batches_with_batch_number — Include storage_location, vendor_batch_number from grn_batches
DROP VIEW IF EXISTS v_grn_all_batches CASCADE;
DROP VIEW IF EXISTS v_grn_batches_with_batch_number CASCADE;

CREATE OR REPLACE VIEW v_grn_batches_with_batch_number AS
SELECT
  gb.id,
  gb.grn_id,
  gb.item_id,
  gb.batch_id,
  COALESCE(
    (SELECT ib.batch_number FROM inventory_batches ib
     WHERE (gb.batch_id IS NOT NULL AND gb.batch_id != '' AND ib.id::text = gb.batch_id)
        OR ((gb.batch_id IS NULL OR gb.batch_id = '') AND ib.received_from_grn_id = gb.grn_id
            AND ib.item_id = gb.item_id AND ((ib.expiry_date::date = gb.expiry_date::date) OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)))
     ORDER BY ib.created_at ASC, ib.id ASC
     LIMIT 1),
    gb.batch_number
  ) AS batch_number,
  gb.expiry_date,
  gb.quantity,
  gb.quantity AS batch_quantity,
  gb.storage_location,
  gb.vendor_batch_number,
  COALESCE(
    (SELECT ib.qc_status FROM inventory_batches ib
     WHERE (gb.batch_id IS NOT NULL AND gb.batch_id != '' AND ib.id::text = gb.batch_id)
        OR ((gb.batch_id IS NULL OR gb.batch_id = '') AND ib.received_from_grn_id = gb.grn_id
            AND ib.item_id = gb.item_id AND ((ib.expiry_date::date = gb.expiry_date::date) OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)))
     ORDER BY ib.created_at ASC, ib.id ASC
     LIMIT 1),
    gb.qc_data->>'qcStatus',
    gb.qc_data->>'qc_status'
  ) AS qc_status,
  gb.qc_data,
  gb.created_at,
  gb.created_by
FROM grn_batches gb;

CREATE OR REPLACE VIEW v_grn_all_batches AS
SELECT * FROM v_grn_batches_with_batch_number
UNION ALL
SELECT
  ib.id,
  ib.received_from_grn_id AS grn_id,
  ib.item_id,
  ib.id::text AS batch_id,
  ib.batch_number,
  ib.expiry_date,
  NULL::numeric AS quantity,
  NULL::numeric AS batch_quantity,
  NULL::text AS storage_location,
  ib.supplier_lot_number AS vendor_batch_number,
  ib.qc_status,
  NULL::text,
  NULL::text,
  ib.created_at,
  NULL::uuid AS created_by
FROM inventory_batches ib
WHERE ib.received_from_grn_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM grn_batches gb
    WHERE gb.grn_id = ib.received_from_grn_id
      AND gb.item_id = ib.item_id
      AND ((gb.expiry_date::date = ib.expiry_date::date) OR (gb.expiry_date IS NULL AND ib.expiry_date IS NULL))
  );

GRANT SELECT ON v_grn_batches_with_batch_number TO authenticated, anon;
GRANT SELECT ON v_grn_all_batches TO authenticated, anon;

-- 6) Backfill: set batch_number for inventory_batches (one-by-one to preserve sequence)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT id, received_from_grn_id, item_id, expiry_date FROM inventory_batches
    WHERE received_from_grn_id IS NOT NULL AND (batch_number IS NULL OR TRIM(batch_number) = '')
    ORDER BY received_from_grn_id, item_id, created_at, id
  LOOP
    UPDATE inventory_batches SET batch_number = fn_generate_batch_number_from_grn(r.received_from_grn_id, r.item_id, r.expiry_date) WHERE id = r.id;
  END LOOP;
END$$;

-- 7) Backfill: sync grn_batches.batch_number and batch_id from inventory_batches (ordinal match)
WITH gb_ranked AS (
  SELECT gb.id, gb.grn_id, gb.item_id, gb.expiry_date,
         row_number() OVER (PARTITION BY gb.grn_id, gb.item_id, COALESCE(gb.expiry_date::date::text, '') ORDER BY gb.created_at, gb.id) AS gb_rn
  FROM grn_batches gb
  WHERE (gb.batch_number IS NULL OR TRIM(gb.batch_number) = '') OR (gb.batch_id IS NULL OR TRIM(gb.batch_id) = '')
),
ib_ranked AS (
  SELECT ib.id, ib.batch_number, ib.received_from_grn_id, ib.item_id, ib.expiry_date,
         row_number() OVER (PARTITION BY ib.received_from_grn_id, ib.item_id, COALESCE(ib.expiry_date::date::text, '') ORDER BY ib.created_at, ib.id) AS ib_rn
  FROM inventory_batches ib
  WHERE ib.received_from_grn_id IS NOT NULL
)
UPDATE grn_batches gb
SET batch_number = ib.batch_number, batch_id = ib.id::text, updated_at = NOW()
FROM gb_ranked gr
JOIN ib_ranked ib ON ib.received_from_grn_id = gr.grn_id AND ib.item_id = gr.item_id
  AND ((ib.expiry_date::date IS NOT DISTINCT FROM gr.expiry_date::date) OR (ib.expiry_date IS NULL AND gr.expiry_date IS NULL))
  AND ib.ib_rn = gr.gb_rn
WHERE gb.id = gr.id;

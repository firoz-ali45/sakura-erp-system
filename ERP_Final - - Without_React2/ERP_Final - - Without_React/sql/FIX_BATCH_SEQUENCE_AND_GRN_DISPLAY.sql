-- ============================================================
-- FIX: BATCH SEQUENCE + GRN BATCH DISPLAY
-- ISSUE 1: Sequence always 001 — fix grn_batch_sequence + function + trigger
-- ISSUE 2: GRN screen shows "—" — create view joining inventory_batches
-- ============================================================
-- RUN IN SUPABASE SQL EDITOR
-- ============================================================

-- ============ ISSUE 1: BATCH SEQUENCE ============

-- Ensure table exists with correct PK
CREATE TABLE IF NOT EXISTS grn_batch_sequence (
  grn_id    uuid NOT NULL,
  item_id   uuid NOT NULL,
  last_seq  integer NOT NULL DEFAULT 0,
  PRIMARY KEY (grn_id, item_id)
);

-- Add item_id if missing (legacy table may have been created without it)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'grn_batch_sequence' AND column_name = 'item_id') THEN
    -- Recreate table with item_id
    DROP TABLE IF EXISTS grn_batch_sequence CASCADE;
    CREATE TABLE grn_batch_sequence (
      grn_id    uuid NOT NULL,
      item_id   uuid NOT NULL,
      last_seq  integer NOT NULL DEFAULT 0,
      PRIMARY KEY (grn_id, item_id)
    );
  END IF;
END $$;

-- Function: atomic next sequence per (grn_id, item_id). Format: BATCH-{GRN_NUMBER}-{YYYYMMDD}-{001,002,003}
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

  -- CRITICAL: item_id MUST be used for sequence key. Never use zero-uuid for same-GRN batches.
  v_key_id := COALESCE(p_item_id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_expiry_str := to_char(COALESCE(p_expiry_date, CURRENT_DATE), 'YYYYMMDD');

  SELECT COALESCE(NULLIF(TRIM(gi.grn_number), ''), 'GRN')
    INTO v_grn_number
  FROM grn_inspections gi
  WHERE gi.id = p_grn_id;

  v_grn_number := regexp_replace(COALESCE(v_grn_number, 'GRN'), '[^A-Za-z0-9-]', '', 'g');
  v_grn_number := COALESCE(NULLIF(v_grn_number, ''), 'GRN');

  -- ATOMIC: INSERT new row OR UPDATE existing. RETURNING gives NEW last_seq after increment.
  INSERT INTO grn_batch_sequence (grn_id, item_id, last_seq)
  VALUES (p_grn_id, v_key_id, 1)
  ON CONFLICT (grn_id, item_id) DO UPDATE SET last_seq = grn_batch_sequence.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN 'BATCH-' || v_grn_number || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Trigger: BEFORE INSERT on inventory_batches. Pass received_from_grn_id, item_id, expiry_date.
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

-- ============ ISSUE 2: GRN BATCH DISPLAY — VIEW WITH inventory_batches.batch_number ============

-- View: grn_batches joined with inventory_batches to get batch_number (single source of truth)
DROP VIEW IF EXISTS v_grn_batches_with_batch_number CASCADE;
CREATE OR REPLACE VIEW v_grn_batches_with_batch_number AS
SELECT
  gb.id,
  gb.grn_id,
  gb.item_id,
  gb.batch_id,
  COALESCE(ib.batch_number, gb.batch_number) AS batch_number,
  gb.expiry_date,
  gb.quantity,
  gb.quantity AS batch_quantity,
  NULL::text AS storage_location,
  NULL::text AS vendor_batch_number,
  COALESCE(ib.qc_status, gb.qc_data->>'qcStatus', gb.qc_data->>'qc_status') AS qc_status,
  gb.qc_data,
  gb.created_at,
  gb.created_by
FROM grn_batches gb
LEFT JOIN inventory_batches ib ON (gb.batch_id IS NOT NULL AND ib.id::text = gb.batch_id)
   OR (ib.received_from_grn_id = gb.grn_id AND ib.item_id = gb.item_id AND ib.expiry_date = gb.expiry_date);

GRANT SELECT ON v_grn_batches_with_batch_number TO authenticated, anon;

-- ============================================================
-- NOTE: loadBatchesForGRN should query v_grn_batches_with_batch_number
-- or join grn_batches with inventory_batches. Frontend service update required.
-- ============================================================

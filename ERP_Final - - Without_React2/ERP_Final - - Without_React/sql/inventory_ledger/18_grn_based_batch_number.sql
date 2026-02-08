-- ============================================================
-- 18: GRN-BASED BATCH NUMBER (unique per GRN batch row)
-- Format: BATCH-{GRN_NUMBER}-{SEQ}  e.g. BATCH-GRN00056-001
-- No ledger/views/UI/RLS/costing changes.
-- ============================================================

-- STEP 1 — sequence table (per GRN)
CREATE TABLE IF NOT EXISTS grn_batch_sequence (
  grn_id    uuid PRIMARY KEY,
  last_seq  integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE grn_batch_sequence IS 'Per-GRN sequence for batch_number suffix.';

-- STEP 2 — function: BATCH-{GRN_NUMBER}-{LPAD(seq,3,'0')}
CREATE OR REPLACE FUNCTION fn_generate_batch_number_from_grn(p_grn_id uuid)
RETURNS text AS $$
DECLARE
  v_grn_number text;
  v_seq        integer;
BEGIN
  IF p_grn_id IS NULL THEN
    RETURN 'BATCH-UNKNOWN-' || lpad((floor(random() * 1000))::text, 3, '0');
  END IF;

  SELECT COALESCE(NULLIF(TRIM(gi.grn_number), ''), 'GRN' || left(p_grn_id::text, 8))
    INTO v_grn_number
  FROM grn_inspections gi
  WHERE gi.id = p_grn_id;

  v_grn_number := regexp_replace(v_grn_number, '[^A-Za-z0-9-]', '', 'g');
  v_grn_number := COALESCE(NULLIF(v_grn_number, ''), 'GRN');

  INSERT INTO grn_batch_sequence (grn_id, last_seq)
  VALUES (p_grn_id, 1)
  ON CONFLICT (grn_id) DO UPDATE SET last_seq = grn_batch_sequence.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN 'BATCH-' || v_grn_number || '-' || lpad(v_seq::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- STEP 3 — BEFORE INSERT trigger on inventory_batches
CREATE OR REPLACE FUNCTION trg_set_batch_number_from_grn()
RETURNS trigger AS $$
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(NEW.batch_number) = '' THEN
    NEW.batch_number := fn_generate_batch_number_from_grn(NEW.received_from_grn_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_batch_number ON inventory_batches;
DROP TRIGGER IF EXISTS trg_generate_batch_number ON inventory_batches;
DROP TRIGGER IF EXISTS trg_set_batch_number_from_grn ON inventory_batches;

CREATE TRIGGER trg_set_batch_number_from_grn
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_set_batch_number_from_grn();

-- STEP 4 — backfill: set batch_number per row using received_from_grn_id (order by GRN, created_at)
DO $$
DECLARE
  r RECORD;
  v_bn text;
BEGIN
  FOR r IN
    SELECT id, received_from_grn_id
    FROM inventory_batches
    WHERE received_from_grn_id IS NOT NULL
    ORDER BY received_from_grn_id, created_at
  LOOP
    v_bn := fn_generate_batch_number_from_grn(r.received_from_grn_id);
    UPDATE inventory_batches SET batch_number = v_bn WHERE id = r.id;
  END LOOP;
END$$;

-- STEP 5 — ensure batch_number unique (global)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_inventory_batches_batch_number'
      AND conrelid = 'inventory_batches'::regclass
  ) THEN
    ALTER TABLE inventory_batches ADD CONSTRAINT uq_inventory_batches_batch_number UNIQUE (batch_number);
  END IF;
END$$;

-- ============================================================
-- 17: AUTO BATCH NUMBER FIX (Database-Side Only)
-- World-class ERP batch numbering: BATCH-{ITEMSKU}-{YYYYMMDD}-{SEQ}
-- No ledger/view/UI/RLS changes. Idempotent. Production-safe.
-- ============================================================

-- -------------------------------------------------------------
-- A. Ensure batch_number column exists
-- -------------------------------------------------------------
ALTER TABLE inventory_batches
  ADD COLUMN IF NOT EXISTS batch_number TEXT;

-- Allow NULL temporarily so BEFORE INSERT trigger can set it when inserter sends NULL
DO $$
BEGIN
  ALTER TABLE inventory_batches ALTER COLUMN batch_number DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;
END$$;

-- -------------------------------------------------------------
-- B. Daily sequence per item (concurrency-safe numbering)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS batch_daily_sequence (
  item_id     UUID NOT NULL,
  batch_date  DATE NOT NULL,
  last_seq    INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (item_id, batch_date)
);

COMMENT ON TABLE batch_daily_sequence IS 'Per-item per-day sequence for batch_number suffix. Used by fn_generate_batch_number.';

-- -------------------------------------------------------------
-- C. Function: generate batch_number (concurrency safe)
-- Format: BATCH-{ITEMSKU}-{YYYYMMDD}-{SEQ}  e.g. BATCH-SK1081-20260205-001
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_generate_batch_number(
  p_item_id      UUID,
  p_expiry_date  DATE
) RETURNS TEXT AS $$
DECLARE
  v_sku       TEXT;
  v_batch_date DATE;
  v_seq       INTEGER;
BEGIN
  v_batch_date := CURRENT_DATE;

  SELECT sku INTO v_sku
  FROM inventory_items
  WHERE id = p_item_id;

  v_sku := COALESCE(NULLIF(TRIM(v_sku), ''), 'ITEM');

  -- Concurrency-safe: get next sequence for (item_id, batch_date)
  INSERT INTO batch_daily_sequence (item_id, batch_date, last_seq)
  VALUES (p_item_id, v_batch_date, 1)
  ON CONFLICT (item_id, batch_date)
  DO UPDATE SET last_seq = batch_daily_sequence.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN 'BATCH-' || v_sku || '-' || to_char(v_batch_date, 'YYYYMMDD') || '-' || lpad(v_seq::TEXT, 3, '0');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_generate_batch_number(UUID, DATE) IS 'Business batch number: BATCH-{SKU}-{YYYYMMDD}-{SEQ}. Concurrency-safe via batch_daily_sequence.';

-- -------------------------------------------------------------
-- D. BEFORE INSERT trigger: set batch_number when NULL
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_generate_batch_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(NEW.batch_number) = '' THEN
    NEW.batch_number := fn_generate_batch_number(NEW.item_id, NEW.expiry_date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_batch_number ON inventory_batches;
DROP TRIGGER IF EXISTS trg_generate_batch_number ON inventory_batches;

CREATE TRIGGER trg_generate_batch_number
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_generate_batch_number();

-- -------------------------------------------------------------
-- E. Backfill: generate batch_number for existing NULL/empty rows
-- Uses same function (batch_date = run date, seq increments per item)
-- -------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
  v_bn TEXT;
BEGIN
  FOR r IN
    SELECT b.id, b.item_id, b.expiry_date
    FROM inventory_batches b
    WHERE b.batch_number IS NULL OR TRIM(b.batch_number) = ''
  LOOP
    v_bn := fn_generate_batch_number(r.item_id, r.expiry_date);
    UPDATE inventory_batches
    SET batch_number = v_bn
    WHERE id = r.id;
  END LOOP;
END$$;

-- -------------------------------------------------------------
-- F. Set NOT NULL only if no NULL/empty remain
-- -------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM inventory_batches
    WHERE batch_number IS NULL OR TRIM(batch_number) = ''
  ) THEN
    ALTER TABLE inventory_batches ALTER COLUMN batch_number SET NOT NULL;
  END IF;
END$$;

-- ============================================================
-- VERIFICATION (run after migration)
-- ============================================================
/*
-- 1) Check batch_number populated
SELECT id, batch_number, item_id, expiry_date, created_at
FROM inventory_batches
ORDER BY created_at DESC
LIMIT 20;

-- 2) Then: Create new GRN → add batch → approve GRN
-- 3) Run again: batch_number must auto appear for new row
SELECT id, batch_number FROM inventory_batches ORDER BY created_at DESC LIMIT 5;

-- 4) Stock Overview: Batch column must show value (not "—")
*/

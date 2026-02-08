-- ============================================================
-- BATCH NUMBER PERSISTENCE (Database-Side)
-- Ensures inventory_batches.batch_number is always set so
-- v_inventory_balance.batch_number and Stock Overview show value.
-- No ledger/view/UI changes. Idempotent.
-- ============================================================

-- -------------------------------------------------------------
-- STEP 1 — Ensure batch_number column exists
-- -------------------------------------------------------------
ALTER TABLE inventory_batches
  ADD COLUMN IF NOT EXISTS batch_number TEXT;

-- Allow NULL on insert so BEFORE INSERT trigger can auto-fill when inserter sends NULL
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'inventory_batches' AND column_name = 'batch_number'
  ) THEN
    ALTER TABLE inventory_batches ALTER COLUMN batch_number DROP NOT NULL;
  END IF;
EXCEPTION
  WHEN OTHERS THEN NULL; -- ignore if already nullable
END$$;

-- -------------------------------------------------------------
-- STEP 2 — Auto-generate batch number (backend safe)
-- Format: BATCH-{item_code}-{YYYYMMDD}-{short_grn}
-- Example: BATCH-SK1081-20260207-ed2a34
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_generate_batch_number(
  p_item_code TEXT,
  p_expiry DATE,
  p_grn_id TEXT
) RETURNS TEXT AS $$
BEGIN
  RETURN
    'BATCH-' ||
    COALESCE(NULLIF(TRIM(p_item_code), ''), 'ITEM') || '-' ||
    to_char(COALESCE(p_expiry, CURRENT_DATE), 'YYYYMMDD') || '-' ||
    left(COALESCE(p_grn_id, ''), 6);
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------
-- STEP 3 — Trigger to ensure persistence on INSERT
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_set_batch_number()
RETURNS TRIGGER AS $$
DECLARE
  v_item_code TEXT;
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(NEW.batch_number) = '' THEN
    SELECT sku INTO v_item_code
    FROM inventory_items
    WHERE id = NEW.item_id;

    NEW.batch_number := fn_generate_batch_number(
      v_item_code,
      NEW.expiry_date,
      NEW.received_from_grn_id::TEXT
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_batch_number ON inventory_batches;

CREATE TRIGGER trg_batch_number
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_set_batch_number();

-- -------------------------------------------------------------
-- STEP 4 — Backfill existing rows where batch_number is empty
-- -------------------------------------------------------------
UPDATE inventory_batches b
SET batch_number = fn_generate_batch_number(
  i.sku,
  b.expiry_date,
  b.received_from_grn_id::TEXT
)
FROM inventory_items i
WHERE b.item_id = i.id
  AND (b.batch_number IS NULL OR TRIM(b.batch_number) = '');

-- Re-apply NOT NULL only if no NULLs remain (trigger fills on insert)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM inventory_batches WHERE batch_number IS NULL OR TRIM(batch_number) = '') THEN
    ALTER TABLE inventory_batches ALTER COLUMN batch_number SET NOT NULL;
  END IF;
END$$;

COMMENT ON FUNCTION fn_generate_batch_number(TEXT, DATE, TEXT) IS 'Business batch number: BATCH-{item_code}-{YYYYMMDD}-{short_grn}. Used by trg_set_batch_number.';

-- ============================================================
-- 21: ALLOW MULTIPLE BATCH ROWS PER (item_id, received_from_grn_id)
-- Each batch = separate row. Remove unique on (item_id, batch_number).
-- Keep UNIQUE(batch_number) only. PK remains id (uuid).
-- No merge. No UI/view change.
-- ============================================================

-- Drop unique that forces one row per (item_id, batch_number) — allows multiple batches same item same GRN
ALTER TABLE inventory_batches
  DROP CONSTRAINT IF EXISTS uq_inventory_batches_item_batch;

-- Ensure batch_number is globally unique (one constraint only)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_inventory_batches_batch_number' AND conrelid = 'inventory_batches'::regclass
  ) THEN
    ALTER TABLE inventory_batches ADD CONSTRAINT uq_inventory_batches_batch_number UNIQUE (batch_number);
  END IF;
END$$;

COMMENT ON TABLE inventory_batches IS 'One row per batch. Multiple rows allowed for same item_id + same received_from_grn_id. batch_number unique globally (e.g. BATCH-GRN-000061-001, 002, 003).';

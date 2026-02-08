-- ============================================================
-- MODULE 2: INVENTORY BATCH / LOT (TRACEABILITY)
-- Optional per item; REQUIRED for expiry tracking, production, cost accuracy.
-- ============================================================

-- item_id references existing inventory_items(id) — do not recreate items table
CREATE TABLE IF NOT EXISTS inventory_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL,
  batch_number text NOT NULL,
  supplier_lot_number text,
  expiry_date date,
  manufacture_date date,
  qc_status text NOT NULL DEFAULT 'HOLD'
    CHECK (qc_status IN ('PASS', 'HOLD', 'FAIL')),
  received_from_grn_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_inventory_batches_item_batch UNIQUE (item_id, batch_number)
);

-- FK to existing inventory_items (do not recreate)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'inventory_batches_item_id_fkey' AND table_name = 'inventory_batches'
  ) AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventory_items') THEN
    ALTER TABLE inventory_batches ADD CONSTRAINT inventory_batches_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE CASCADE;
  END IF;
END$$;

COMMENT ON TABLE inventory_batches IS 'Batch/lot traceability. Optional per item; required for expiry, production, cost accuracy.';
COMMENT ON COLUMN inventory_batches.received_from_grn_id IS 'GRN (grn_inspections.id) that received this batch.';

CREATE INDEX IF NOT EXISTS idx_inventory_batches_item ON inventory_batches(item_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_expiry ON inventory_batches(expiry_date);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_grn ON inventory_batches(received_from_grn_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_qc ON inventory_batches(qc_status);

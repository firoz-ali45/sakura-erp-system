-- ============================================================
-- MODULE 3: INVENTORY STOCK LEDGER (IMMUTABLE — HEART OF SYSTEM)
-- Golden rule: never store current stock; always derive from ledger.
-- STRICT: qty_in > 0 OR qty_out > 0 (never both). NO UPDATE. NO DELETE. Only INSERT.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_movement_type') THEN
    CREATE TYPE inventory_movement_type AS ENUM (
      'GRN',
      'TRANSFER_IN',
      'TRANSFER_OUT',
      'PRODUCTION_CONSUMPTION',
      'PRODUCTION_OUTPUT',
      'SALE',
      'ADJUSTMENT_IN',
      'ADJUSTMENT_OUT',
      'SCRAP',
      'EXPIRED',
      'RETURN'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_reference_type') THEN
    CREATE TYPE inventory_reference_type AS ENUM (
      'PR', 'PO', 'GRN', 'PUR', 'TRANSFER', 'PRODUCTION', 'SALE', 'ADJUSTMENT'
    );
  END IF;
END$$;

-- If old ledger exists (has "warehouse" text column, no "location_id"), rename to _legacy so new table can be created.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger' AND column_name = 'warehouse')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger' AND column_name = 'location_id') THEN
      ALTER TABLE inventory_stock_ledger RENAME TO inventory_stock_ledger_legacy;
      RAISE NOTICE 'Renamed old inventory_stock_ledger to inventory_stock_ledger_legacy (no location_id). New table will be created.';
    END IF;
  END IF;
END$$;

-- item_id -> inventory_items(id), location_id -> inventory_locations(id). Do not alter PR/PO/GRN.
CREATE TABLE IF NOT EXISTS inventory_stock_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL,
  location_id uuid NOT NULL,
  batch_id uuid,
  qty_in numeric(18,4) NOT NULL DEFAULT 0,
  qty_out numeric(18,4) NOT NULL DEFAULT 0,
  unit_cost numeric(18,4) NOT NULL DEFAULT 0,
  total_cost numeric(18,2) NOT NULL DEFAULT 0,
  movement_type inventory_movement_type NOT NULL,
  reference_type inventory_reference_type NOT NULL,
  reference_id text,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_ledger_qty_in_or_out CHECK (
    (qty_in > 0 AND qty_out = 0) OR (qty_out > 0 AND qty_in = 0)
  ),
  CONSTRAINT chk_ledger_qty_positive CHECK (qty_in >= 0 AND qty_out >= 0)
);

-- FKs to inventory_locations and optional inventory_batches; item_id to existing inventory_items
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'inventory_stock_ledger_location_id_fkey' AND table_name = 'inventory_stock_ledger') 
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'inventory_stock_ledger' AND column_name = 'location_id') THEN
    ALTER TABLE inventory_stock_ledger ADD CONSTRAINT inventory_stock_ledger_location_id_fkey
      FOREIGN KEY (location_id) REFERENCES inventory_locations(id) ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'inventory_stock_ledger_batch_id_fkey' AND table_name = 'inventory_stock_ledger') THEN
    ALTER TABLE inventory_stock_ledger ADD CONSTRAINT inventory_stock_ledger_batch_id_fkey
      FOREIGN KEY (batch_id) REFERENCES inventory_batches(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'inventory_stock_ledger_item_id_fkey' AND table_name = 'inventory_stock_ledger')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventory_items') THEN
    ALTER TABLE inventory_stock_ledger ADD CONSTRAINT inventory_stock_ledger_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE RESTRICT;
  END IF;
END$$;

COMMENT ON TABLE inventory_stock_ledger IS 'Immutable stock ledger. Single source of truth. Only INSERT allowed; no UPDATE/DELETE.';
COMMENT ON CONSTRAINT chk_ledger_qty_in_or_out ON inventory_stock_ledger IS 'Exactly one of qty_in or qty_out must be positive.';

CREATE INDEX IF NOT EXISTS idx_inventory_stock_ledger_item ON inventory_stock_ledger(item_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_ledger_location ON inventory_stock_ledger(location_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_ledger_batch ON inventory_stock_ledger(batch_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_ledger_ref ON inventory_stock_ledger(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_ledger_created ON inventory_stock_ledger(created_at);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_ledger_movement ON inventory_stock_ledger(movement_type);

-- Revoke UPDATE/DELETE; allow only INSERT and SELECT (enforced by trigger in 06)
-- RLS and grants: production-safe, adjust as per project.
ALTER TABLE inventory_stock_ledger ENABLE ROW LEVEL SECURITY;

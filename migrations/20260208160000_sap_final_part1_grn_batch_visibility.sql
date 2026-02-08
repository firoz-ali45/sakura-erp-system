-- ============================================================
-- SAP-LEVEL CORRECTION — PART 1: GRN BATCH VISIBILITY
-- Batch format ITEMCODE-001 (global per item). stock_batches. Views.
-- ============================================================

-- 1. Global per-item batch sequence (ITEMCODE-001, ITEMCODE-002, ...)
CREATE TABLE IF NOT EXISTS item_batch_sequence (
  item_id uuid PRIMARY KEY REFERENCES inventory_items(id) ON DELETE CASCADE,
  last_seq integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE item_batch_sequence IS 'Global batch sequence per item for format ITEMCODE-001, ITEMCODE-002.';

-- 2. Function: next batch number for item (ITEMCODE-001)
CREATE OR REPLACE FUNCTION fn_next_item_batch_number(p_item_id uuid)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_sku text;
  v_seq integer;
BEGIN
  SELECT COALESCE(NULLIF(TRIM(sku), ''), 'ITEM') INTO v_sku FROM inventory_items WHERE id = p_item_id;
  IF v_sku IS NULL THEN v_sku := 'ITEM'; END IF;
  v_sku := UPPER(regexp_replace(v_sku, '[^A-Za-z0-9]', '', 'g'));
  IF v_sku = '' THEN v_sku := 'ITEM'; END IF;

  INSERT INTO item_batch_sequence (item_id, last_seq, updated_at)
  VALUES (p_item_id, 1, now())
  ON CONFLICT (item_id) DO UPDATE SET last_seq = item_batch_sequence.last_seq + 1, updated_at = now()
  RETURNING last_seq INTO v_seq;

  RETURN v_sku || '-' || lpad(v_seq::text, 3, '0');
END;
$$;

-- 3. stock_batches: one row per GRN batch line (id, item_id, grn_id, batch_no, expiry, qty_received, remaining_qty)
CREATE TABLE IF NOT EXISTS stock_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
  grn_id uuid NOT NULL REFERENCES grn_inspections(id) ON DELETE CASCADE,
  batch_no text NOT NULL,
  expiry_date date,
  qty_received numeric(18,4) NOT NULL DEFAULT 0,
  remaining_qty numeric(18,4) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(grn_id, item_id, batch_no)
);

CREATE INDEX IF NOT EXISTS idx_stock_batches_item ON stock_batches(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_batches_grn ON stock_batches(grn_id);
CREATE INDEX IF NOT EXISTS idx_stock_batches_batch_no ON stock_batches(batch_no);

COMMENT ON TABLE stock_batches IS 'GRN batch lines with remaining qty. Synced from grn_batches/inventory_batches and ledger.';

-- 4. Add remaining_qty to grn_batches if missing (for sync)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'grn_batches' AND column_name = 'remaining_qty') THEN
    ALTER TABLE grn_batches ADD COLUMN remaining_qty numeric(18,4) DEFAULT 0;
  END IF;
END$$;

-- 5. v_item_batches_full: item → all batches → remaining qty
CREATE OR REPLACE VIEW v_item_batches_full AS
SELECT
  b.id AS batch_id,
  b.item_id,
  i.sku AS item_code,
  i.name AS item_name,
  b.grn_id,
  b.batch_no,
  b.expiry_date,
  b.qty_received,
  b.remaining_qty,
  b.created_at
FROM stock_batches b
JOIN inventory_items i ON i.id = b.item_id
WHERE b.remaining_qty > 0;

-- 6. v_grn_batch_summary: for GRN grid "3 batches" or single batch_no
CREATE OR REPLACE VIEW v_grn_batch_summary AS
SELECT
  grn_id,
  COUNT(*) AS batch_count,
  CASE WHEN COUNT(*) = 1 THEN MAX(batch_no) ELSE (COUNT(*)::text || ' batches') END AS display_batch
FROM stock_batches
GROUP BY grn_id;

-- 7. Stock overview aggregation: SUM(remaining_qty), batch count, latest batch numbers
CREATE OR REPLACE VIEW v_stock_overview_batches AS
SELECT
  b.item_id,
  i.sku AS item_code,
  i.name AS item_name,
  COUNT(*) AS batch_count,
  SUM(b.remaining_qty) AS total_remaining_qty,
  array_agg(b.batch_no ORDER BY b.created_at DESC) FILTER (WHERE b.remaining_qty > 0) AS batch_numbers
FROM stock_batches b
JOIN inventory_items i ON i.id = b.item_id
WHERE b.remaining_qty > 0
GROUP BY b.item_id, i.id, i.sku, i.name;

-- 8. Trigger: on grn_batches insert → insert stock_batches with ITEMCODE-NNN
CREATE OR REPLACE FUNCTION fn_sync_grn_batch_to_stock_batches()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_batch_no text;
  v_item_id uuid;
BEGIN
  v_item_id := COALESCE(NEW.item_id, (SELECT item_id FROM grn_inspection_items WHERE grn_inspection_id = NEW.grn_id LIMIT 1));
  IF v_item_id IS NULL THEN RETURN NEW; END IF;
  v_batch_no := COALESCE(NULLIF(TRIM(NEW.batch_number), ''), fn_next_item_batch_number(v_item_id));
  INSERT INTO stock_batches (item_id, grn_id, batch_no, expiry_date, qty_received, remaining_qty)
  VALUES (v_item_id, NEW.grn_id, v_batch_no, (NEW.expiry_date::date), COALESCE(NEW.quantity, 0), COALESCE(NEW.quantity, 0))
  ON CONFLICT (grn_id, item_id, batch_no) DO UPDATE SET qty_received = EXCLUDED.qty_received, remaining_qty = EXCLUDED.remaining_qty;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_grn_batches_to_stock_batches ON grn_batches;
CREATE TRIGGER trg_grn_batches_to_stock_batches
  AFTER INSERT OR UPDATE OF quantity, batch_number, item_id, expiry_date ON grn_batches
  FOR EACH ROW EXECUTE FUNCTION fn_sync_grn_batch_to_stock_batches();

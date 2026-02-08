-- ============================================================
-- 19: LEDGER BATCH_ID BACKFILL (fix NULL batch_id for GRN rows)
-- 1) Create missing inventory_batches for ledger rows that have none.
-- 2) Set ledger.batch_id from inventory_batches. No UI/view/schema change.
-- ============================================================

-- Allow UPDATE on ledger for this one-time backfill
DROP TRIGGER IF EXISTS trg_inventory_stock_ledger_no_update ON inventory_stock_ledger;
DROP TRIGGER IF EXISTS trg_inventory_stock_ledger_no_delete ON inventory_stock_ledger;

-- Step 1: Create missing inventory_batches for (item_id, grn_id) that have ledger rows with batch_id NULL
-- (batch_number filled by BEFORE INSERT trigger fn_generate_batch_number_from_grn)
INSERT INTO inventory_batches (item_id, received_from_grn_id, qc_status)
SELECT DISTINCT l.item_id, l.reference_id::uuid, 'HOLD'
FROM inventory_stock_ledger l
WHERE l.reference_type = 'GRN'
  AND l.batch_id IS NULL
  AND l.reference_id IS NOT NULL
  AND l.reference_id ~ '^[0-9a-fA-F-]{36}$'
  AND NOT EXISTS (
    SELECT 1 FROM inventory_batches b
    WHERE b.item_id = l.item_id AND b.received_from_grn_id = l.reference_id::uuid
  );

-- Step 2: Backfill ledger — set batch_id from inventory_batches (item_id + reference_id = grn_id)
UPDATE inventory_stock_ledger l
SET batch_id = sub.batch_id
FROM (
  SELECT
    l2.id AS ledger_id,
    (
      SELECT b.id
      FROM inventory_batches b
      WHERE b.item_id = l2.item_id
        AND b.received_from_grn_id::text = l2.reference_id
      ORDER BY b.created_at, b.id
      LIMIT 1
    ) AS batch_id
  FROM inventory_stock_ledger l2
  WHERE l2.reference_type = 'GRN'
    AND l2.batch_id IS NULL
    AND l2.reference_id IS NOT NULL
) sub
WHERE l.id = sub.ledger_id AND sub.batch_id IS NOT NULL;

-- Restore immutability
CREATE TRIGGER trg_inventory_stock_ledger_no_update
  BEFORE UPDATE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION trg_inventory_stock_ledger_immutable();
CREATE TRIGGER trg_inventory_stock_ledger_no_delete
  BEFORE DELETE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION trg_inventory_stock_ledger_immutable();

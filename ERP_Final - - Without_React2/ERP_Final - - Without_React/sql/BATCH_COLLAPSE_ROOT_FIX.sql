-- ============================================================
-- BATCH COLLAPSE + QTY ZERO — ROOT FIX
-- ISSUE A: 3 batches collapse to 1 after approval
-- ISSUE B: Batches tab empty after approval  
-- ISSUE C: Batch qty becomes 0
-- ISSUE D: Sequence always 001
-- ROOT: No batch delete/merge in approval. Fix view + fn + loader.
-- ============================================================
-- RUN IN SUPABASE SQL EDITOR (after GRN_BATCH_PR_FLOW_ROOT_FIX.sql if needed)
-- ============================================================

-- ============ 1. BATCH SEQUENCE — per (grn_id, item_id), NEVER collapse ============
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

DROP TRIGGER IF EXISTS trg_set_batch_number_from_grn ON inventory_batches;
CREATE TRIGGER trg_set_batch_number_from_grn
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_set_batch_number_from_grn();


-- ============ 2. SYNC grn_batches (batch_number, batch_id) — NEVER touch quantity ============
CREATE OR REPLACE FUNCTION trg_sync_grn_batches_after_inv_batch()
RETURNS trigger AS $$
BEGIN
  UPDATE grn_batches
  SET batch_number = NEW.batch_number,
      batch_id = NEW.id::text,
      updated_at = NOW()
  WHERE grn_id = NEW.received_from_grn_id
    AND item_id = NEW.item_id
    AND (expiry_date::date = NEW.expiry_date::date OR (expiry_date IS NULL AND NEW.expiry_date IS NULL));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_grn_batches_after_inv_batch ON inventory_batches;
CREATE TRIGGER trg_sync_grn_batches_after_inv_batch
  AFTER INSERT ON inventory_batches
  FOR EACH ROW
  WHEN (NEW.received_from_grn_id IS NOT NULL)
  EXECUTE FUNCTION trg_sync_grn_batches_after_inv_batch();


-- ============ 3. v_grn_batches_with_batch_number — ONE row per grn_batch, quantity preserved ============
-- Use DISTINCT ON to ensure one row per grn_batches.id (no collapse from join)
DROP VIEW IF EXISTS v_grn_all_batches CASCADE;
DROP VIEW IF EXISTS v_grn_batches_with_batch_number CASCADE;

-- One row per grn_batch; batch_number from inventory_batches via scalar subquery (no join collapse)
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
            AND ib.item_id = gb.item_id AND (ib.expiry_date::date = gb.expiry_date::date OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)))
     ORDER BY ib.batch_number NULLS LAST
     LIMIT 1),
    gb.batch_number
  ) AS batch_number,
  gb.expiry_date,
  gb.quantity,
  gb.quantity AS batch_quantity,
  NULL::text AS storage_location,
  NULL::text AS vendor_batch_number,
  COALESCE(
    (SELECT ib.qc_status FROM inventory_batches ib
     WHERE (gb.batch_id IS NOT NULL AND gb.batch_id != '' AND ib.id::text = gb.batch_id)
        OR ((gb.batch_id IS NULL OR gb.batch_id = '') AND ib.received_from_grn_id = gb.grn_id
            AND ib.item_id = gb.item_id AND (ib.expiry_date::date = gb.expiry_date::date OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)))
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
  NULL::jsonb AS qc_data,
  ib.created_at,
  NULL::uuid AS created_by
FROM inventory_batches ib
WHERE ib.received_from_grn_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM grn_batches gb
    WHERE gb.grn_id = ib.received_from_grn_id
      AND gb.item_id = ib.item_id
      AND (gb.expiry_date::date = ib.expiry_date::date OR (gb.expiry_date IS NULL AND ib.expiry_date IS NULL))
  );

GRANT SELECT ON v_grn_batches_with_batch_number TO authenticated, anon;
GRANT SELECT ON v_grn_all_batches TO authenticated, anon;


-- ============ 4. Ensure getGRNById loads batches (frontend) — batches loaded via loadBatchesForGRN ============
-- No DB change; frontend must call loadBatchesForGRN for grn_id. Already done in loadGRN.

-- ============ 5. CRITICAL: Never merge/delete batches on approval ============
-- Audit: No trigger or function should DELETE FROM grn_batches or GROUP BY item_id only.
-- The inventory_ledger trigger ONLY reads grn_batches and inserts into inventory_stock_ledger.
-- It does NOT modify grn_batches. Verified.

-- ============================================================
-- VALIDATION: Run after migration
-- SELECT id, grn_id, item_id, batch_number, quantity FROM v_grn_all_batches WHERE grn_id = 'your-grn-uuid' ORDER BY created_at;
-- ============================================================

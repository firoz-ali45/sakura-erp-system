-- ============================================================
-- 18: FIX LEDGER → BATCH LINK (GRN approval)
-- Ensures inventory_stock_ledger.batch_id is always set when GRN
-- has batches, so v_inventory_balance.batch_number appears in UI.
-- No view/ledger structure/UI changes. Idempotent.
-- Prerequisite: run 17_auto_batch_number_fix.sql (fn_generate_batch_number).
-- ============================================================

-- -------------------------------------------------------------
-- PART 1: Fix GRN approval trigger — always resolve batch_id
-- When grn_batches.batch_number is NULL, generate and ensure
-- inventory_batches row exists, then link ledger to it.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_inventory_ledger_on_grn_approval()
RETURNS TRIGGER AS $$
DECLARE
  v_item RECORD;
  v_batch RECORD;
  v_location_id uuid;
  v_warehouse_text text;
  v_unit_cost numeric(18,4);
  v_po_id bigint;
  v_batch_id uuid;
  v_has_grn_batches boolean;
  v_batch_number text;
BEGIN
  IF NEW.status NOT IN ('approved', 'passed') OR (OLD.status IS NOT NULL AND OLD.status IN ('approved', 'passed')) THEN
    RETURN NEW;
  END IF;

  v_warehouse_text := COALESCE(TRIM(NEW.receiving_location), 'Main Warehouse (W01)');

  SELECT id INTO v_location_id
  FROM inventory_locations
  WHERE is_active = true
    AND location_type = 'WAREHOUSE'
    AND (
      location_name = v_warehouse_text
      OR location_code = regexp_replace(v_warehouse_text, '^.*\(([^)]+)\)\s*$', '\1')
      OR location_name = split_part(v_warehouse_text, ' (', 1)
    )
  LIMIT 1;

  IF v_location_id IS NULL THEN
    SELECT id INTO v_location_id
    FROM inventory_locations
    WHERE is_active = true AND location_type = 'WAREHOUSE' AND allow_grn = true
    ORDER BY created_at
    LIMIT 1;
  END IF;

  IF v_location_id IS NULL THEN
    RAISE WARNING 'inventory_ledger: No active WAREHOUSE location found for GRN %. Ledger not posted.', NEW.grn_number;
    RETURN NEW;
  END IF;

  v_po_id := NEW.purchase_order_id;

  SELECT EXISTS (SELECT 1 FROM grn_batches WHERE grn_id = NEW.id AND COALESCE(quantity, 0) > 0) INTO v_has_grn_batches;

  IF v_has_grn_batches THEN
    FOR v_batch IN
      SELECT gb.item_id, gb.quantity AS qty, gb.batch_number, gb.expiry_date
      FROM grn_batches gb
      WHERE gb.grn_id = NEW.id AND COALESCE(gb.quantity, 0) > 0
    LOOP
      v_batch_id := NULL;
      v_batch_number := NULLIF(TRIM(v_batch.batch_number), '');

      -- When grn_batches.batch_number is missing, generate so we can still link
      IF v_batch_number IS NULL THEN
        v_batch_number := fn_generate_batch_number(v_batch.item_id, v_batch.expiry_date);
      END IF;

      -- Resolve inventory_batches row (lookup or create)
      IF v_batch_number IS NOT NULL THEN
        SELECT id INTO v_batch_id
        FROM inventory_batches
        WHERE item_id = v_batch.item_id AND batch_number = v_batch_number
        LIMIT 1;

        IF v_batch_id IS NULL THEN
          INSERT INTO inventory_batches (item_id, batch_number, expiry_date, received_from_grn_id, qc_status)
          VALUES (v_batch.item_id, v_batch_number, v_batch.expiry_date, NEW.id, 'HOLD')
          ON CONFLICT (item_id, batch_number) DO UPDATE SET received_from_grn_id = EXCLUDED.received_from_grn_id
          RETURNING id INTO v_batch_id;
        END IF;
      END IF;

      SELECT COALESCE(poi.unit_price, 0) INTO v_unit_cost
      FROM purchase_order_items poi
      WHERE poi.item_id = v_batch.item_id AND poi.purchase_order_id = v_po_id
      LIMIT 1;
      IF v_unit_cost IS NULL THEN
        v_unit_cost := 0;
      END IF;

      INSERT INTO inventory_stock_ledger (
        item_id,
        location_id,
        batch_id,
        qty_in,
        qty_out,
        unit_cost,
        total_cost,
        movement_type,
        reference_type,
        reference_id,
        created_by
      ) VALUES (
        v_batch.item_id,
        v_location_id,
        v_batch_id,
        v_batch.qty,
        0,
        v_unit_cost,
        v_batch.qty * v_unit_cost,
        'GRN'::inventory_movement_type,
        'GRN'::inventory_reference_type,
        NEW.id::text,
        COALESCE(NEW.approved_by_name, NEW.created_by::text, 'System')
      );
    END LOOP;
  ELSE
    FOR v_item IN
      SELECT
        gii.item_id,
        gii.received_quantity AS qty,
        COALESCE(poi.unit_price, 0) AS unit_price
      FROM grn_inspection_items gii
      LEFT JOIN purchase_order_items poi ON poi.item_id = gii.item_id
        AND poi.purchase_order_id = v_po_id
      WHERE gii.grn_inspection_id = NEW.id
        AND COALESCE(gii.received_quantity, 0) > 0
    LOOP
      v_unit_cost := COALESCE(v_item.unit_price, 0);
      INSERT INTO inventory_stock_ledger (
        item_id,
        location_id,
        batch_id,
        qty_in,
        qty_out,
        unit_cost,
        total_cost,
        movement_type,
        reference_type,
        reference_id,
        created_by
      ) VALUES (
        v_item.item_id,
        v_location_id,
        NULL,
        v_item.qty,
        0,
        v_unit_cost,
        v_item.qty * v_unit_cost,
        'GRN'::inventory_movement_type,
        'GRN'::inventory_reference_type,
        NEW.id::text,
        COALESCE(NEW.approved_by_name, NEW.created_by::text, 'System')
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------
-- PART 2a: Create missing inventory_batches for GRN ledger rows
-- (Ledger was written with batch_id NULL when no batch existed.)
-- One batch per (item_id, reference_id = GRN id).
-- -------------------------------------------------------------
INSERT INTO inventory_batches (item_id, batch_number, expiry_date, received_from_grn_id, qc_status)
SELECT
  g.item_id,
  fn_generate_batch_number(g.item_id, g.dt),
  g.dt,
  g.grn_id,
  'HOLD'
FROM (
  SELECT l.item_id, l.reference_id::uuid AS grn_id, min(l.created_at)::date AS dt
  FROM inventory_stock_ledger l
  WHERE l.reference_type = 'GRN'
    AND l.batch_id IS NULL
    AND l.reference_id IS NOT NULL
    AND l.reference_id ~ '^[0-9a-fA-F-]{36}$'
  GROUP BY l.item_id, l.reference_id
) g
WHERE g.grn_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM inventory_batches b
    WHERE b.item_id = g.item_id AND b.received_from_grn_id = g.grn_id
  )
ON CONFLICT (item_id, batch_number) DO NOTHING;

-- -------------------------------------------------------------
-- PART 2b: Backfill ledger — set batch_id from inventory_batches
-- Ledger is normally immutable (no UPDATE). Temporarily allow UPDATE
-- for this one-time backfill only, then restore immutability.
-- -------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_inventory_stock_ledger_no_update ON inventory_stock_ledger;
DROP TRIGGER IF EXISTS trg_inventory_stock_ledger_no_delete ON inventory_stock_ledger;

UPDATE inventory_stock_ledger l
SET batch_id = b.id
FROM inventory_batches b
WHERE l.reference_type = 'GRN'
  AND l.batch_id IS NULL
  AND l.item_id = b.item_id
  AND b.received_from_grn_id::text = l.reference_id;

-- Restore immutability (triggers from 06_inventory_constraints.sql)
CREATE TRIGGER trg_inventory_stock_ledger_no_update
  BEFORE UPDATE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION trg_inventory_stock_ledger_immutable();
CREATE TRIGGER trg_inventory_stock_ledger_no_delete
  BEFORE DELETE ON inventory_stock_ledger
  FOR EACH ROW EXECUTE FUNCTION trg_inventory_stock_ledger_immutable();

-- ============================================================
-- VERIFICATION (run after migration)
-- ============================================================
/*
-- 1) Ledger must have batch_id and join to batch_number
SELECT l.id, l.item_id, l.batch_id, b.batch_number, l.reference_id
FROM inventory_stock_ledger l
LEFT JOIN inventory_batches b ON l.batch_id = b.id
WHERE l.reference_type = 'GRN'
ORDER BY l.created_at DESC
LIMIT 20;

-- 2) View must show batch_number
SELECT item_id, item_name, location_name, batch_id, batch_number, current_qty
FROM v_inventory_balance
ORDER BY item_name, location_name
LIMIT 20;

-- 3) After new GRN + batch + approve: batch_number must appear in Stock Overview
*/

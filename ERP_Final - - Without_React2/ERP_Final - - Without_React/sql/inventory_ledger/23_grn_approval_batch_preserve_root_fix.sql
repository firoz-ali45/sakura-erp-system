-- ============================================================
-- 23: GRN APPROVAL BATCH PRESERVE — ROOT FIX
-- ISSUE: 3 batches collapse to 1, qty becomes 0 after approval
-- ROOT: Ensure approval NEVER deletes/merges/overwrites grn_batches.
-- Batch data becomes permanent immutable inventory record on approval.
-- ============================================================
-- Run in Supabase SQL Editor after 04_inventory_triggers.sql
-- ============================================================

-- ============ 1. HARDEN: trg_sync_grn_batches_after_inv_batch — NEVER touch quantity ============
CREATE OR REPLACE FUNCTION trg_sync_grn_batches_after_inv_batch()
RETURNS trigger AS $$
BEGIN
  -- ONLY update batch_number and batch_id. NEVER modify quantity.
  UPDATE grn_batches
  SET batch_number = COALESCE(NULLIF(TRIM(grn_batches.batch_number), ''), NEW.batch_number),
      batch_id = COALESCE(NULLIF(TRIM(grn_batches.batch_id), ''), NEW.id::text),
      updated_at = NOW()
  WHERE grn_id = NEW.received_from_grn_id
    AND item_id = NEW.item_id
    AND (expiry_date::date IS NOT DISTINCT FROM (NEW.expiry_date)::date
         OR (expiry_date IS NULL AND NEW.expiry_date IS NULL));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============ 2. SAFEGUARD: Prevent grn_batches.quantity from being zeroed ============
CREATE OR REPLACE FUNCTION trg_grn_batches_protect_quantity()
RETURNS trigger AS $$
BEGIN
  -- If quantity was positive and is being set to 0 or negative, block it
  IF OLD.quantity IS NOT NULL AND (OLD.quantity::numeric) > 0
     AND (NEW.quantity IS NULL OR (NEW.quantity::numeric) <= 0) THEN
    RAISE EXCEPTION 'grn_batches.quantity cannot be set to zero or negative once set (id=%). Batch quantities are immutable.', OLD.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_grn_batches_protect_quantity ON grn_batches;
CREATE TRIGGER trg_grn_batches_protect_quantity
  BEFORE UPDATE OF quantity ON grn_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_grn_batches_protect_quantity();


-- ============ 3. BATCH SEQUENCE: Use ROW_NUMBER per (grn_id, item_id) ORDER BY expiry, created_at ============
-- Format: BATCH-GRN-{grn_number}-{YYYYMMDD}-{SEQ}
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

  -- Sequence = COUNT of existing inventory_batches for (grn_id, item_id) + 1
  -- Use advisory lock to avoid race
  PERFORM pg_advisory_xact_lock(hashtext(p_grn_id::text || '-' || v_key_id::text));
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
  FROM inventory_batches
  WHERE received_from_grn_id = p_grn_id AND item_id = v_key_id;

  RETURN 'BATCH-' || v_grn_number || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$$ LANGUAGE plpgsql;


-- ============ 4. v_grn_batches_with_batch_number — ONE row per grn_batch, quantity preserved, no collapse ============
DROP VIEW IF EXISTS v_grn_all_batches CASCADE;
DROP VIEW IF EXISTS v_grn_batches_with_batch_number CASCADE;

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
            AND ib.item_id = gb.item_id AND ((ib.expiry_date::date = gb.expiry_date::date) OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)))
     ORDER BY ib.created_at ASC, ib.id ASC
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
            AND ib.item_id = gb.item_id AND ((ib.expiry_date::date = gb.expiry_date::date) OR (ib.expiry_date IS NULL AND gb.expiry_date IS NULL)))
     ORDER BY ib.created_at ASC, ib.id ASC
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
      AND ((gb.expiry_date::date = ib.expiry_date::date) OR (gb.expiry_date IS NULL AND ib.expiry_date IS NULL))
  );

GRANT SELECT ON v_grn_batches_with_batch_number TO authenticated, anon;
GRANT SELECT ON v_grn_all_batches TO authenticated, anon;


-- ============ 5. HARDEN trg_inventory_ledger_on_grn_approval — NEVER modify grn_batches, one row per batch ============
-- Recreate to ensure: loop over ALL grn_batches with qty>0, use v_batch.qty, never aggregate
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

  -- ONE ROW PER GRN_BATCH: never aggregate, never merge
  SELECT EXISTS (SELECT 1 FROM grn_batches WHERE grn_id = NEW.id AND COALESCE(quantity, 0) > 0) INTO v_has_grn_batches;

  IF v_has_grn_batches THEN
    FOR v_batch IN
      SELECT gb.id AS gb_id, gb.item_id, gb.quantity AS qty, gb.batch_id, gb.batch_number, gb.expiry_date, gb.created_at AS gb_created_at
      FROM grn_batches gb
      WHERE gb.grn_id = NEW.id AND COALESCE(gb.quantity, 0) > 0
      ORDER BY gb.created_at, gb.id
    LOOP
      v_batch_id := NULL;
      v_batch_number := NULLIF(TRIM(v_batch.batch_number), '');

      -- 1) Use batch_id if already set
      IF v_batch.batch_id IS NOT NULL AND NULLIF(TRIM(v_batch.batch_id), '') IS NOT NULL THEN
        SELECT id INTO v_batch_id
        FROM inventory_batches
        WHERE id::text = v_batch.batch_id;
      END IF;

      -- 2) Use batch_number + item_id if set
      IF v_batch_id IS NULL AND v_batch_number IS NOT NULL THEN
        SELECT id INTO v_batch_id
        FROM inventory_batches
        WHERE item_id = v_batch.item_id AND batch_number = v_batch_number
        LIMIT 1;
      END IF;

      -- 3) Resolve by (item_id + expiry + received_from_grn_id) with ordinal match
      IF v_batch_id IS NULL THEN
        SELECT sub.id INTO v_batch_id
        FROM (
          SELECT id, row_number() OVER (ORDER BY created_at, id) AS rn
          FROM inventory_batches
          WHERE item_id = v_batch.item_id
            AND received_from_grn_id = NEW.id
            AND ((expiry_date IS NOT DISTINCT FROM (v_batch.expiry_date)::date)
                 OR (expiry_date IS NULL AND v_batch.expiry_date IS NULL))
        ) sub
        WHERE sub.rn = (
          SELECT count(*)::int FROM grn_batches g2
          WHERE g2.grn_id = NEW.id AND g2.item_id = v_batch.item_id
            AND ((g2.expiry_date)::date IS NOT DISTINCT FROM (v_batch.expiry_date)::date
                 OR (g2.expiry_date IS NULL AND v_batch.expiry_date IS NULL))
            AND (g2.created_at, g2.id) <= (v_batch.gb_created_at, v_batch.gb_id)
        );
      END IF;

      -- 4) Create only if not found — one inventory_batch per grn_batch
      IF v_batch_id IS NULL THEN
        INSERT INTO inventory_batches (item_id, expiry_date, received_from_grn_id, qc_status)
        VALUES (v_batch.item_id, (v_batch.expiry_date)::date, NEW.id, 'HOLD')
        RETURNING id INTO v_batch_id;
      END IF;

      SELECT COALESCE(poi.unit_price, 0) INTO v_unit_cost
      FROM purchase_order_items poi
      WHERE poi.item_id = v_batch.item_id AND poi.purchase_order_id = v_po_id
      LIMIT 1;
      IF v_unit_cost IS NULL THEN v_unit_cost := 0; END IF;

      -- Post ledger: use v_batch.qty (NEVER aggregate)
      INSERT INTO inventory_stock_ledger (
        item_id, location_id, batch_id, qty_in, qty_out,
        unit_cost, total_cost, movement_type, reference_type, reference_id, created_by
      ) VALUES (
        v_batch.item_id, v_location_id, v_batch_id,
        v_batch.qty, 0,
        v_unit_cost, v_batch.qty * v_unit_cost,
        'GRN'::inventory_movement_type, 'GRN'::inventory_reference_type,
        NEW.id::text, COALESCE(NEW.approved_by_name, NEW.created_by::text, 'System')
      );
    END LOOP;
  ELSE
    -- Fallback: no grn_batches, post per grn_inspection_item with batch_id NULL
    FOR v_item IN
      SELECT gii.item_id, gii.received_quantity AS qty, COALESCE(poi.unit_price, 0) AS unit_price
      FROM grn_inspection_items gii
      LEFT JOIN purchase_order_items poi ON poi.item_id = gii.item_id AND poi.purchase_order_id = v_po_id
      WHERE gii.grn_inspection_id = NEW.id AND COALESCE(gii.received_quantity, 0) > 0
    LOOP
      v_unit_cost := COALESCE(v_item.unit_price, 0);
      INSERT INTO inventory_stock_ledger (
        item_id, location_id, batch_id, qty_in, qty_out,
        unit_cost, total_cost, movement_type, reference_type, reference_id, created_by
      ) VALUES (
        v_item.item_id, v_location_id, NULL,
        v_item.qty, 0,
        v_unit_cost, v_item.qty * v_unit_cost,
        'GRN'::inventory_movement_type, 'GRN'::inventory_reference_type,
        NEW.id::text, COALESCE(NEW.approved_by_name, NEW.created_by::text, 'System')
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============ 6. Ensure trg_set_batch_number_from_grn uses expiry in format ============
CREATE OR REPLACE FUNCTION trg_set_batch_number_from_grn()
RETURNS trigger AS $$
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(COALESCE(NEW.batch_number, '')) = '' THEN
    NEW.batch_number := fn_generate_batch_number_from_grn(NEW.received_from_grn_id, NEW.item_id, NEW.expiry_date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_batch_number_from_grn ON inventory_batches;
CREATE TRIGGER trg_set_batch_number_from_grn
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_set_batch_number_from_grn();

DROP TRIGGER IF EXISTS trg_sync_grn_batches_after_inv_batch ON inventory_batches;
CREATE TRIGGER trg_sync_grn_batches_after_inv_batch
  AFTER INSERT ON inventory_batches
  FOR EACH ROW
  WHEN (NEW.received_from_grn_id IS NOT NULL)
  EXECUTE FUNCTION trg_sync_grn_batches_after_inv_batch();

-- ============================================================
-- VALIDATION
-- After migration: Create 1 GRN, add 3 batches (qty 2 each), approve.
-- Expect: 3 batches remain, qty 2 each, sequence 001/002/003.
-- ============================================================

-- ============================================================
-- MODULE 4: AUTOMATIC LEDGER POSTINGS (TRIGGERS)
-- Does not alter existing grn_inspections / grn_inspection_items schema.
-- 1) ON GRN APPROVAL: qty_in, unit_cost from PO, movement_type GRN.
-- 2) ON TRANSFER: qty_out source, qty_in destination. 3) PRODUCTION: RM qty_out, FG qty_in.
-- 4) ON SALE (future): qty_out from BRANCH.
-- ============================================================

-- ----- 1) GRN APPROVAL -> Ledger qty_in (destination = WAREHOUSE) -----
-- Posts one row per grn_batch so batch_id and batch_number appear in v_inventory_balance.
-- If no grn_batches exist for this GRN, falls back to one row per grn_inspection_item with batch_id NULL.
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
BEGIN
  IF NEW.status NOT IN ('approved', 'passed') OR (OLD.status IS NOT NULL AND OLD.status IN ('approved', 'passed')) THEN
    RETURN NEW;
  END IF;

  v_warehouse_text := COALESCE(TRIM(NEW.receiving_location), 'Main Warehouse (W01)');

  -- Resolve receiving_location (text) to inventory_locations.id
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

  -- Prefer grn_batches: one ledger row per batch with batch_id set (so v_inventory_balance shows batch_number)
  SELECT EXISTS (SELECT 1 FROM grn_batches WHERE grn_id = NEW.id AND COALESCE(quantity, 0) > 0) INTO v_has_grn_batches;

  IF v_has_grn_batches THEN
    FOR v_batch IN
      SELECT gb.id AS gb_id, gb.item_id, gb.quantity AS qty, gb.batch_number, gb.expiry_date, gb.created_at AS gb_created_at
      FROM grn_batches gb
      WHERE gb.grn_id = NEW.id AND COALESCE(gb.quantity, 0) > 0
      ORDER BY gb.created_at, gb.id
    LOOP
      v_batch_id := NULL;

      -- 1) Resolve batch_id by (item_id + expiry_date + received_from_grn_id); when multiple batches match, use same ordinal as this grn_batch
      SELECT sub.id INTO v_batch_id
      FROM (
        SELECT id, row_number() OVER (ORDER BY created_at, id) AS rn
        FROM inventory_batches
        WHERE item_id = v_batch.item_id
          AND received_from_grn_id = NEW.id
          AND (expiry_date IS NOT DISTINCT FROM (v_batch.expiry_date)::date)
      ) sub
      WHERE sub.rn = (
        SELECT count(*)::int FROM grn_batches g2
        WHERE g2.grn_id = NEW.id AND g2.item_id = v_batch.item_id
          AND ((g2.expiry_date)::date IS NOT DISTINCT FROM (v_batch.expiry_date)::date)
          AND (g2.created_at, g2.id) <= (v_batch.gb_created_at, v_batch.gb_id)
      );

      -- 2) If not found, create inventory_batches row (batch_number from GRN-based generator) so ledger never gets NULL batch_id
      IF v_batch_id IS NULL THEN
        INSERT INTO inventory_batches (item_id, expiry_date, received_from_grn_id, qc_status)
        VALUES (v_batch.item_id, (v_batch.expiry_date)::date, NEW.id, 'HOLD')
        RETURNING id INTO v_batch_id;
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
    -- Fallback: no grn_batches, post per grn_inspection_item with batch_id NULL
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

DROP TRIGGER IF EXISTS trg_inventory_ledger_grn_approval ON grn_inspections;
CREATE TRIGGER trg_inventory_ledger_grn_approval
  AFTER UPDATE OF status ON grn_inspections
  FOR EACH ROW
  EXECUTE FUNCTION trg_inventory_ledger_on_grn_approval();

-- ----- 2) TRANSFER: qty_out from source, qty_in to destination (cost copied) -----
-- Requires transfer header table (e.g. inventory_transfers) with source_location_id, dest_location_id, reference_id.
-- Placeholder: create function and trigger when transfer table exists.
CREATE OR REPLACE FUNCTION trg_inventory_ledger_on_transfer()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' OR (OLD.status = 'completed') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  -- Insert qty_out rows for each transfer line from source_location_id
  -- Insert qty_in rows for each transfer line to dest_location_id
  -- Implement when inventory_transfers + inventory_transfer_lines exist
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ----- 3) PRODUCTION: RM consumption qty_out, FG output qty_in; FG cost = SUM(RM cost)/FG qty -----
CREATE OR REPLACE FUNCTION trg_inventory_ledger_on_production()
RETURNS TRIGGER AS $$
BEGIN
  -- Implement when production orders / BOM consumption and output tables exist
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ----- 4) SALE (future): qty_out from BRANCH -----
CREATE OR REPLACE FUNCTION trg_inventory_ledger_on_sale()
RETURNS TRIGGER AS $$
BEGIN
  -- Implement when sales/pos tables exist; movement_type = SALE, reference_type = SALE
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

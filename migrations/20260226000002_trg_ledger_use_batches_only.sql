-- Fix: relation "inventory_batches" does not exist
-- Production uses batches + grn_batches. Ledger.batch_id references batches(id).
-- Rewrite trigger to use batches.id (gb.id) directly — no inventory_batches.

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
  v_created_by uuid;
BEGIN
  v_created_by := COALESCE(NEW.approved_by, NEW.created_by);
  IF NEW.status NOT IN ('approved', 'passed') OR (OLD.status IS NOT NULL AND OLD.status IN ('approved', 'passed')) THEN
    RETURN NEW;
  END IF;

  v_warehouse_text := COALESCE(TRIM(NEW.receiving_location), 'Main Warehouse (W01)');

  SELECT id INTO v_location_id
  FROM inventory_locations
  WHERE is_active = true AND location_type = 'WAREHOUSE'
    AND (location_name = v_warehouse_text OR location_code = regexp_replace(v_warehouse_text, '^.*\(([^)]+)\)\s*$', '\1') OR location_name = split_part(v_warehouse_text, ' (', 1))
  LIMIT 1;

  IF v_location_id IS NULL THEN
    SELECT id INTO v_location_id FROM inventory_locations
    WHERE is_active = true AND location_type = 'WAREHOUSE' AND (allow_grn = true OR allow_grn IS NULL)
    ORDER BY created_at LIMIT 1;
  END IF;

  IF v_location_id IS NULL THEN
    RAISE WARNING 'inventory_ledger: No active WAREHOUSE location found for GRN %. Ledger not posted.', NEW.grn_number;
    RETURN NEW;
  END IF;

  v_po_id := NEW.purchase_order_id;
  SELECT EXISTS (SELECT 1 FROM grn_batches WHERE grn_id = NEW.id AND COALESCE(quantity, 0) > 0) INTO v_has_grn_batches;

  IF v_has_grn_batches THEN
    FOR v_batch IN
      SELECT gb.id AS gb_id, gb.item_id, gb.quantity AS qty, gb.batch_number, gb.expiry_date
      FROM grn_batches gb
      WHERE gb.grn_id = NEW.id AND COALESCE(gb.quantity, 0) > 0
      ORDER BY gb.created_at, gb.id
    LOOP
      v_batch_id := v_batch.gb_id;

      SELECT COALESCE(poi.unit_price, 0) INTO v_unit_cost
      FROM purchase_order_items poi
      WHERE poi.item_id = v_batch.item_id AND poi.purchase_order_id = v_po_id
      LIMIT 1;
      IF v_unit_cost IS NULL THEN v_unit_cost := 0; END IF;

      INSERT INTO inventory_stock_ledger (
        item_id, location_id, batch_id, qty_in, qty_out,
        unit_cost, total_cost, movement_type, reference_type, reference_id, created_by
      ) VALUES (
        v_batch.item_id, v_location_id, v_batch_id,
        v_batch.qty, 0,
        v_unit_cost, v_batch.qty * v_unit_cost,
        'GRN'::inventory_movement_type, 'GRN'::inventory_reference_type,
        NEW.id::text, v_created_by
      );
    END LOOP;
  ELSE
    FOR v_item IN
      SELECT gii.item_id, gii.received_quantity AS qty, COALESCE(poi.unit_price, 0) AS unit_price
      FROM grn_inspection_items gii
      LEFT JOIN purchase_order_items poi ON poi.item_id = gii.item_id AND poi.purchase_order_id = v_po_id
      WHERE gii.grn_inspection_id = NEW.id AND COALESCE(gii.received_quantity, 0) > 0
    LOOP
      INSERT INTO inventory_stock_ledger (
        item_id, location_id, batch_id, qty_in, qty_out,
        unit_cost, total_cost, movement_type, reference_type, reference_id, created_by
      ) VALUES (
        v_item.item_id, v_location_id, NULL,
        v_item.qty, 0,
        COALESCE(v_item.unit_price, 0), v_item.qty * COALESCE(v_item.unit_price, 0),
        'GRN'::inventory_movement_type, 'GRN'::inventory_reference_type,
        NEW.id::text, v_created_by
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

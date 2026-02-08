-- ============================================================
-- COMPLETE DATA FLOW FIX FOR PO ↔ GRN QUANTITIES
-- ============================================================
-- Problem: PO shows Received = 0 even after GRN receives items
-- This script diagnoses AND fixes the data flow
-- ============================================================

-- ============================================================
-- PART 1: DIAGNOSTIC QUERIES (Run these first to see what's happening)
-- ============================================================

-- 1A: Check table column types
SELECT 'purchase_orders.id type:' AS check_type, data_type 
FROM information_schema.columns 
WHERE table_name = 'purchase_orders' AND column_name = 'id';

SELECT 'purchase_order_items.purchase_order_id type:' AS check_type, data_type 
FROM information_schema.columns 
WHERE table_name = 'purchase_order_items' AND column_name = 'purchase_order_id';

SELECT 'grn_inspections.purchase_order_number type:' AS check_type, data_type 
FROM information_schema.columns 
WHERE table_name = 'grn_inspections' AND column_name = 'purchase_order_number';

SELECT 'grn_inspection_items.item_id type:' AS check_type, data_type 
FROM information_schema.columns 
WHERE table_name = 'grn_inspection_items' AND column_name = 'item_id';

-- 1B: Check if grn_inspections has purchase_order_number set
SELECT 
    gi.id AS grn_id,
    gi.grn_number,
    gi.purchase_order_number,
    gi.status,
    (SELECT COUNT(*) FROM grn_inspection_items gii WHERE gii.grn_inspection_id = gi.id) AS item_count
FROM grn_inspections gi
WHERE gi.deleted = false
ORDER BY gi.created_at DESC
LIMIT 10;

-- 1C: Check grn_inspection_items data
SELECT 
    gii.id,
    gii.grn_inspection_id,
    gii.item_id,
    gii.item_code,
    gii.item_name,
    gii.ordered_quantity,
    gii.received_quantity,
    gi.purchase_order_number
FROM grn_inspection_items gii
INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
WHERE gi.deleted = false
ORDER BY gi.created_at DESC
LIMIT 20;

-- 1D: Check purchase_order_items data
SELECT 
    poi.id AS po_item_id,
    poi.purchase_order_id,
    poi.item_id,
    poi.item_name,
    poi.item_sku,
    poi.quantity,
    poi.quantity_received,
    po.po_number
FROM purchase_order_items poi
INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id
WHERE po.status IN ('approved', 'partially_received', 'fully_received')
ORDER BY po.created_at DESC
LIMIT 20;

-- 1E: CRITICAL - Check if item_ids match between PO and GRN
SELECT 
    'MATCHING ITEMS' AS diagnosis,
    po.po_number,
    poi.item_id AS po_item_id,
    poi.item_name AS po_item_name,
    poi.quantity AS ordered,
    gi.purchase_order_number AS grn_po_number,
    gii.item_id AS grn_item_id,
    gii.item_name AS grn_item_name,
    gii.received_quantity AS received,
    CASE WHEN poi.item_id = gii.item_id THEN '✅ MATCH' ELSE '❌ NO MATCH' END AS item_id_match
FROM purchase_orders po
INNER JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
LEFT JOIN grn_inspections gi ON gi.purchase_order_number = po.po_number AND gi.deleted = false
LEFT JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id
WHERE po.status IN ('approved', 'partially_received', 'fully_received')
ORDER BY po.po_number;

-- ============================================================
-- PART 2: DROP OLD VIEW AND CREATE CORRECTED VIEW
-- ============================================================

DROP VIEW IF EXISTS v_po_item_receipts CASCADE;

-- This VIEW calculates received quantities by:
-- 1. Linking PO to GRN via purchase_order_number (TEXT to TEXT)
-- 2. Linking items via item_id (UUID to UUID)
-- 3. Only counting non-deleted, non-cancelled GRNs

CREATE VIEW v_po_item_receipts AS
SELECT 
    poi.id AS po_item_id,
    poi.purchase_order_id,
    po.po_number AS purchase_order_number,
    poi.item_id,
    poi.item_name,
    poi.item_sku AS item_code,
    COALESCE(poi.quantity, 0)::NUMERIC AS ordered_qty,
    COALESCE(
        (
            SELECT SUM(COALESCE(gii.received_quantity, 0))
            FROM grn_inspection_items gii
            INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
            WHERE gi.purchase_order_number = po.po_number
              AND gii.item_id = poi.item_id
              AND COALESCE(gi.deleted, false) = false
              AND gi.status NOT IN ('cancelled', 'rejected')
        ), 
        0
    )::NUMERIC AS received_qty,
    GREATEST(
        COALESCE(poi.quantity, 0) - COALESCE(
            (
                SELECT SUM(COALESCE(gii.received_quantity, 0))
                FROM grn_inspection_items gii
                INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
                WHERE gi.purchase_order_number = po.po_number
                  AND gii.item_id = poi.item_id
                  AND COALESCE(gi.deleted, false) = false
                  AND gi.status NOT IN ('cancelled', 'rejected')
            ), 
            0
        ),
        0
    )::NUMERIC AS remaining_qty
FROM purchase_order_items poi
INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id;

-- Grant access
GRANT SELECT ON v_po_item_receipts TO authenticated;
GRANT SELECT ON v_po_item_receipts TO anon;

-- ============================================================
-- PART 3: VERIFY VIEW WORKS
-- ============================================================

-- Run this to verify:
SELECT 
    purchase_order_number,
    item_id,
    item_name,
    ordered_qty,
    received_qty,
    remaining_qty
FROM v_po_item_receipts
WHERE received_qty > 0
ORDER BY purchase_order_number;

-- ============================================================
-- PART 4: IF item_id DOESN'T MATCH, USE item_code/item_sku INSTEAD
-- ============================================================
-- Sometimes item_id is not set correctly in GRN items.
-- This alternative VIEW joins using item_code/item_sku instead:

DROP VIEW IF EXISTS v_po_item_receipts_by_code CASCADE;

CREATE VIEW v_po_item_receipts_by_code AS
SELECT 
    poi.id AS po_item_id,
    poi.purchase_order_id,
    po.po_number AS purchase_order_number,
    poi.item_id,
    poi.item_name,
    poi.item_sku AS item_code,
    COALESCE(poi.quantity, 0)::NUMERIC AS ordered_qty,
    COALESCE(
        (
            SELECT SUM(COALESCE(gii.received_quantity, 0))
            FROM grn_inspection_items gii
            INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
            WHERE gi.purchase_order_number = po.po_number
              AND (
                  -- Try matching by item_id first
                  gii.item_id = poi.item_id
                  -- Or by item_code/item_sku if item_id is NULL
                  OR (gii.item_id IS NULL AND gii.item_code IS NOT NULL AND gii.item_code = poi.item_sku)
              )
              AND COALESCE(gi.deleted, false) = false
              AND gi.status NOT IN ('cancelled', 'rejected')
        ), 
        0
    )::NUMERIC AS received_qty,
    GREATEST(
        COALESCE(poi.quantity, 0) - COALESCE(
            (
                SELECT SUM(COALESCE(gii.received_quantity, 0))
                FROM grn_inspection_items gii
                INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
                WHERE gi.purchase_order_number = po.po_number
                  AND (
                      gii.item_id = poi.item_id
                      OR (gii.item_id IS NULL AND gii.item_code IS NOT NULL AND gii.item_code = poi.item_sku)
                  )
                  AND COALESCE(gi.deleted, false) = false
                  AND gi.status NOT IN ('cancelled', 'rejected')
            ), 
            0
        ),
        0
    )::NUMERIC AS remaining_qty
FROM purchase_order_items poi
INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id;

GRANT SELECT ON v_po_item_receipts_by_code TO authenticated;
GRANT SELECT ON v_po_item_receipts_by_code TO anon;

-- ============================================================
-- PART 5: BACKFILL purchase_order_items.quantity_received
-- ============================================================

-- First ensure column exists
ALTER TABLE purchase_order_items 
ADD COLUMN IF NOT EXISTS quantity_received NUMERIC DEFAULT 0;

-- Backfill from VIEW
UPDATE purchase_order_items poi
SET quantity_received = COALESCE(
    (SELECT v.received_qty FROM v_po_item_receipts v WHERE v.po_item_id = poi.id),
    0
);

-- ============================================================
-- PART 6: CREATE TRIGGER TO AUTO-UPDATE ON GRN CHANGES
-- ============================================================

-- Drop existing triggers
DROP TRIGGER IF EXISTS trg_grn_item_insert ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_item_update ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_item_delete ON grn_inspection_items;

-- Create/replace trigger function
CREATE OR REPLACE FUNCTION trg_sync_po_received_qty()
RETURNS TRIGGER AS $$
DECLARE
    v_po_number TEXT;
    v_item_id UUID;
    v_po_id INTEGER;
    v_total_received NUMERIC;
BEGIN
    -- Get item_id based on operation
    IF TG_OP = 'DELETE' THEN
        v_item_id := OLD.item_id;
        SELECT purchase_order_number INTO v_po_number
        FROM grn_inspections WHERE id = OLD.grn_inspection_id;
    ELSE
        v_item_id := NEW.item_id;
        SELECT purchase_order_number INTO v_po_number
        FROM grn_inspections WHERE id = NEW.grn_inspection_id;
    END IF;
    
    -- Skip if no PO number linked
    IF v_po_number IS NULL OR v_po_number = '' THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Get PO ID
    SELECT id INTO v_po_id FROM purchase_orders WHERE po_number = v_po_number;
    
    IF v_po_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Calculate total received for this item across all GRNs
    SELECT COALESCE(SUM(gii.received_quantity), 0) INTO v_total_received
    FROM grn_inspection_items gii
    INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_number = v_po_number
      AND gii.item_id = v_item_id
      AND COALESCE(gi.deleted, false) = false
      AND gi.status NOT IN ('cancelled', 'rejected');
    
    -- Update purchase_order_items
    UPDATE purchase_order_items
    SET quantity_received = v_total_received
    WHERE purchase_order_id = v_po_id AND item_id = v_item_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER trg_grn_item_insert
    AFTER INSERT ON grn_inspection_items
    FOR EACH ROW EXECUTE FUNCTION trg_sync_po_received_qty();

CREATE TRIGGER trg_grn_item_update
    AFTER UPDATE OF received_quantity ON grn_inspection_items
    FOR EACH ROW EXECUTE FUNCTION trg_sync_po_received_qty();

CREATE TRIGGER trg_grn_item_delete
    AFTER DELETE ON grn_inspection_items
    FOR EACH ROW EXECUTE FUNCTION trg_sync_po_received_qty();

-- ============================================================
-- PART 7: FINAL VERIFICATION
-- ============================================================

-- Run this after completing all steps:
SELECT 
    'VERIFICATION' AS status,
    v.purchase_order_number,
    v.item_name,
    v.ordered_qty,
    v.received_qty,
    v.remaining_qty,
    poi.quantity_received AS stored_received
FROM v_po_item_receipts v
LEFT JOIN purchase_order_items poi ON poi.id = v.po_item_id
WHERE v.received_qty > 0 OR poi.quantity_received > 0
ORDER BY v.purchase_order_number;

-- ============================================================
-- COMPLETION
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ DATA FLOW FIX COMPLETE';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'WHAT WAS FIXED:';
    RAISE NOTICE '1. v_po_item_receipts VIEW created (primary source of truth)';
    RAISE NOTICE '2. v_po_item_receipts_by_code VIEW created (fallback by item_code)';
    RAISE NOTICE '3. Triggers created to auto-sync on GRN changes';
    RAISE NOTICE '4. Existing data backfilled';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT STEPS:';
    RAISE NOTICE '1. Refresh the PO detail page';
    RAISE NOTICE '2. Create a new GRN for a PO';
    RAISE NOTICE '3. Verify received/remaining quantities update';
    RAISE NOTICE '';
END $$;

-- ============================================================
-- FIX GRN ITEM IDs BY MATCHING VIA ITEM CODE/SKU
-- ============================================================
-- Problem: grn_inspection_items.item_id doesn't match purchase_order_items.item_id
-- Solution: Update GRN item_ids to match inventory_items by item_code/sku

-- STEP 1: Check current state - GRN items with NULL or mismatched item_ids
SELECT 
    gii.id AS grn_item_id,
    gii.item_id AS current_item_id,
    gii.item_code,
    gii.item_name,
    ii.id AS correct_item_id,
    ii.sku AS inventory_sku,
    ii.name AS inventory_name
FROM grn_inspection_items gii
LEFT JOIN inventory_items ii ON (
    ii.sku = gii.item_code 
    OR ii.code = gii.item_code
    OR LOWER(ii.name) = LOWER(gii.item_name)
)
WHERE gii.item_id IS NULL 
   OR gii.item_id != ii.id
LIMIT 30;

-- STEP 2: FIX - Update GRN item_ids to match inventory_items by item_code
UPDATE grn_inspection_items gii
SET item_id = ii.id
FROM inventory_items ii
WHERE (
    ii.sku = gii.item_code 
    OR ii.code = gii.item_code
)
AND gii.item_code IS NOT NULL
AND (gii.item_id IS NULL OR gii.item_id != ii.id);

-- STEP 3: FIX - Update by item_name if item_code didn't match
UPDATE grn_inspection_items gii
SET item_id = ii.id
FROM inventory_items ii
WHERE LOWER(ii.name) = LOWER(gii.item_name)
AND gii.item_name IS NOT NULL
AND gii.item_id IS NULL;

-- STEP 4: Now recalculate PO received quantities using the updated item_ids
-- This will use the triggers we created

-- Force recalculate for all POs
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT DISTINCT po.po_number, poi.item_id
        FROM purchase_order_items poi
        INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id
        WHERE poi.item_id IS NOT NULL
    LOOP
        BEGIN
            PERFORM update_po_item_received_quantity(r.po_number, r.item_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error updating % / %: %', r.po_number, r.item_id, SQLERRM;
        END;
    END LOOP;
    
    FOR r IN SELECT DISTINCT po_number FROM purchase_orders WHERE po_number IS NOT NULL
    LOOP
        BEGIN
            PERFORM update_po_receiving_status(r.po_number);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error updating PO status %: %', r.po_number, SQLERRM;
        END;
    END LOOP;
END $$;

-- STEP 5: Verify the fix
SELECT 
    v.purchase_order_number,
    v.item_name,
    v.ordered_qty,
    v.received_qty,
    v.remaining_qty
FROM v_po_item_receipts v
WHERE v.received_qty > 0
ORDER BY v.purchase_order_number;

-- STEP 6: Check PO #56 specifically
SELECT * FROM v_po_item_receipts WHERE purchase_order_number LIKE '%56%';

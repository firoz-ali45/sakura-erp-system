-- ============================================================
-- DIAGNOSTIC: VERIFY PO → GRN DATA FLOW
-- ============================================================
-- Run each section separately and share results

-- ============================================================
-- STEP 1: Check grn_inspection_items structure
-- ============================================================
SELECT 
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'grn_inspection_items'
ORDER BY ordinal_position;

-- ============================================================
-- STEP 2: Check if grn_inspection_items has purchase_order_id column
-- ============================================================
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'grn_inspection_items'
  AND column_name IN ('purchase_order_id', 'item_id', 'received_quantity', 'grn_inspection_id');

-- ============================================================
-- STEP 3: Check grn_inspections structure (focus on PO linking)
-- ============================================================
SELECT 
    column_name, 
    data_type
FROM information_schema.columns
WHERE table_name = 'grn_inspections'
  AND column_name IN ('id', 'purchase_order_id', 'purchase_order_number', 'status', 'deleted');

-- ============================================================
-- STEP 4: Check purchase_orders structure
-- ============================================================
SELECT 
    column_name, 
    data_type
FROM information_schema.columns
WHERE table_name = 'purchase_orders'
  AND column_name IN ('id', 'po_number');

-- ============================================================
-- STEP 5: Check purchase_order_items structure
-- ============================================================
SELECT 
    column_name, 
    data_type
FROM information_schema.columns
WHERE table_name = 'purchase_order_items'
  AND column_name IN ('id', 'purchase_order_id', 'item_id', 'quantity', 'quantity_received');

-- ============================================================
-- STEP 6: CRITICAL - See actual GRN inspection items data
-- ============================================================
SELECT 
    gii.id AS grn_item_id,
    gii.grn_inspection_id,
    gii.item_id,
    gii.received_quantity,
    gi.purchase_order_number AS grn_po_number,
    gi.status AS grn_status,
    gi.deleted AS grn_deleted
FROM grn_inspection_items gii
INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
LIMIT 20;

-- ============================================================
-- STEP 7: CRITICAL - See actual PO items data
-- ============================================================
SELECT 
    poi.id AS po_item_id,
    poi.purchase_order_id,
    poi.item_id,
    poi.quantity AS ordered_qty,
    poi.quantity_received,
    po.po_number
FROM purchase_order_items poi
INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id
WHERE po.status = 'approved'
LIMIT 20;

-- ============================================================
-- STEP 8: CRITICAL - Test the JOIN logic
-- Check if item_ids actually match between GRN and PO
-- ============================================================
SELECT 
    po.po_number,
    poi.item_id AS po_item_id,
    poi.quantity AS ordered_qty,
    gii.item_id AS grn_item_id,
    gii.received_quantity,
    gi.purchase_order_number AS grn_po_number,
    gi.status AS grn_status,
    CASE 
        WHEN poi.item_id = gii.item_id THEN 'MATCH'
        ELSE 'NO MATCH'
    END AS item_id_match
FROM purchase_order_items poi
INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id
LEFT JOIN grn_inspections gi ON gi.purchase_order_number = po.po_number
LEFT JOIN grn_inspection_items gii ON gii.grn_inspection_id = gi.id
WHERE po.status = 'approved'
ORDER BY po.po_number, poi.item_id
LIMIT 50;

-- ============================================================
-- STEP 9: Check VIEW results
-- ============================================================
SELECT * FROM v_po_item_receipts LIMIT 20;

-- ============================================================
-- STEP 10: Specific PO test - Replace 'PO-XXXXX' with actual PO number
-- ============================================================
-- First find a PO that has GRN:
SELECT DISTINCT gi.purchase_order_number 
FROM grn_inspections gi 
WHERE gi.purchase_order_number IS NOT NULL 
  AND gi.deleted = false
LIMIT 10;

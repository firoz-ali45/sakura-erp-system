-- ============================================================
-- DEBUG PO #56 SPECIFICALLY
-- ============================================================

-- STEP 1: Check PO #56 details
SELECT 
    id,
    po_number,
    status,
    total_received_quantity
FROM purchase_orders 
WHERE id = 56 OR po_number LIKE '%56%';

-- STEP 2: Check PO #56 items
SELECT 
    poi.id AS po_item_id,
    poi.purchase_order_id,
    poi.item_id,
    poi.item_name,
    poi.item_sku,
    poi.quantity AS ordered,
    poi.quantity_received
FROM purchase_order_items poi
WHERE poi.purchase_order_id = 56;

-- STEP 3: Check ALL GRNs - what purchase_order_number do they have?
SELECT 
    gi.id AS grn_id,
    gi.grn_number,
    gi.purchase_order_number,
    gi.purchase_order_id,
    gi.status,
    gi.deleted
FROM grn_inspections gi
WHERE gi.deleted = false
ORDER BY gi.created_at DESC
LIMIT 15;

-- STEP 4: Find GRN for PO #56 (by po_number)
SELECT 
    gi.id AS grn_id,
    gi.grn_number,
    gi.purchase_order_number,
    gi.status
FROM grn_inspections gi
WHERE gi.purchase_order_number LIKE '%56%'
   OR gi.purchase_order_number = 'PO-000056';

-- STEP 5: Check GRN items for that GRN
-- (Replace 'YOUR_GRN_ID' with the GRN ID from step 4)
SELECT 
    gii.id,
    gii.grn_inspection_id,
    gii.item_id AS grn_item_id,
    gii.item_code,
    gii.item_name,
    gii.received_quantity
FROM grn_inspection_items gii
WHERE gii.grn_inspection_id IN (
    SELECT gi.id FROM grn_inspections gi 
    WHERE gi.purchase_order_number LIKE '%56%'
);

-- STEP 6: CRITICAL - Compare item_ids between PO and GRN
SELECT 
    'COMPARISON' AS check_type,
    poi.item_id AS po_item_id,
    poi.item_name AS po_item_name,
    gii.item_id AS grn_item_id,
    gii.item_name AS grn_item_name,
    gii.received_quantity,
    CASE WHEN poi.item_id = gii.item_id THEN '✅ MATCH' ELSE '❌ NO MATCH' END AS match_status
FROM purchase_order_items poi
CROSS JOIN grn_inspection_items gii
WHERE poi.purchase_order_id = 56
  AND gii.grn_inspection_id IN (
      SELECT gi.id FROM grn_inspections gi 
      WHERE gi.purchase_order_number LIKE '%56%'
  );

-- STEP 7: Check v_po_item_receipts for PO #56
SELECT * FROM v_po_item_receipts 
WHERE purchase_order_number LIKE '%56%';

-- STEP 8: Find the actual item_id from inventory for sk-1074
SELECT id, name, sku FROM inventory_items WHERE sku = 'sk-1074';

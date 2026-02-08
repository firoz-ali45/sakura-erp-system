-- Quick Fix: Update PO Item Received Quantities
-- Run this script for a specific PO to immediately update received quantities
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID

-- Option 1: Update all POs
DO $$
DECLARE
    po_record RECORD;
BEGIN
    FOR po_record IN SELECT id FROM purchase_orders LOOP
        PERFORM update_po_received_quantities(po_record.id);
    END LOOP;
    RAISE NOTICE '✅ Updated all PO quantities';
END $$;

-- Option 2: Update a specific PO (uncomment and replace PO ID)
/*
SELECT update_po_received_quantities('YOUR_PO_ID_HERE');
*/

-- Option 3: Check current status of a specific PO
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID
/*
SELECT 
    po.id,
    po.po_number,
    po.status,
    po.ordered_quantity,
    po.total_received_quantity,
    po.remaining_quantity,
    (SELECT COUNT(*) FROM purchase_order_items WHERE purchase_order_id = po.id) as items_count,
    (SELECT COUNT(*) FROM grn_inspections WHERE purchase_order_id = po.id AND deleted = false) as grn_count
FROM purchase_orders po
WHERE po.id = 'YOUR_PO_ID_HERE';
*/

-- Option 4: Check PO items with received quantities
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID
/*
SELECT 
    poi.id,
    poi.item_id,
    poi.quantity as ordered_qty,
    poi.quantity_received,
    (poi.quantity - poi.quantity_received) as remaining_qty,
    i.name as item_name,
    i.sku as item_sku
FROM purchase_order_items poi
LEFT JOIN inventory_items i ON i.id = poi.item_id
WHERE poi.purchase_order_id = 'YOUR_PO_ID_HERE'
ORDER BY poi.id;
*/

-- Option 5: Verify GRN items for a PO
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID
/*
SELECT 
    gi.id as grn_id,
    gi.grn_number,
    gi.status as grn_status,
    gii.item_id,
    gii.received_quantity,
    i.name as item_name,
    i.sku as item_sku
FROM grn_inspections gi
INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
LEFT JOIN inventory_items i ON i.id = gii.item_id
WHERE gi.purchase_order_id = 'YOUR_PO_ID_HERE'
AND gi.deleted = false
ORDER BY gi.created_at DESC, gii.item_id;
*/


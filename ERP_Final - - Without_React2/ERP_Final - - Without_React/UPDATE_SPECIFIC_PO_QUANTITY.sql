-- Update Specific PO Quantities Manually
-- Replace YOUR_PO_ID with your actual PO ID (e.g., 40, 41, 42, etc.)
-- Run this in Supabase SQL Editor

-- Option 1: Update a specific PO (replace 40 with your PO ID)
SELECT update_po_received_quantities(40);

-- Option 2: Check PO quantities before and after update
-- Replace 40 with your PO ID
/*
-- Before update
SELECT 
    po.id,
    po.po_number,
    po.status,
    po.ordered_quantity,
    po.total_received_quantity,
    po.remaining_quantity
FROM purchase_orders po
WHERE po.id = 40;

-- Update
SELECT update_po_received_quantities(40);

-- After update
SELECT 
    po.id,
    po.po_number,
    po.status,
    po.ordered_quantity,
    po.total_received_quantity,
    po.remaining_quantity
FROM purchase_orders po
WHERE po.id = 40;
*/

-- Option 3: Check PO items with received quantities
-- Replace 40 with your PO ID
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
WHERE poi.purchase_order_id = 40
ORDER BY poi.id;
*/

-- Option 4: Check GRNs for this PO
-- Replace 40 with your PO ID
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
WHERE gi.purchase_order_id = 40
AND gi.deleted = false
ORDER BY gi.created_at DESC, gii.item_id;
*/



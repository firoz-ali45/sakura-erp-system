-- Verification Script: Check PO and GRN Quantities
-- Run this SQL in Supabase SQL Editor to verify that PO items show correct received quantities
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID

-- Step 1: Find a PO with GRNs to test
SELECT 
    po.id as po_id,
    po.po_number,
    po.status as po_status,
    po.ordered_quantity as po_ordered_qty,
    po.total_received_quantity as po_received_qty,
    po.remaining_quantity as po_remaining_qty,
    COUNT(DISTINCT gi.id) as grn_count
FROM purchase_orders po
LEFT JOIN grn_inspections gi ON gi.purchase_order_id = po.id AND gi.deleted = false
GROUP BY po.id, po.po_number, po.status, po.ordered_quantity, po.total_received_quantity, po.remaining_quantity
HAVING COUNT(DISTINCT gi.id) > 0
ORDER BY po.created_at DESC
LIMIT 10;

-- Step 2: Check PO items and their received quantities for a specific PO
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID from Step 1
/*
SELECT 
    poi.id as po_item_id,
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

-- Step 3: Check GRNs for a specific PO and their items
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID
/*
SELECT 
    gi.id as grn_id,
    gi.grn_number,
    gi.status as grn_status,
    gi.purchase_order_id,
    gii.item_id,
    gii.received_quantity,
    gii.ordered_quantity,
    i.name as item_name,
    i.sku as item_sku
FROM grn_inspections gi
INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
LEFT JOIN inventory_items i ON i.id = gii.item_id
WHERE gi.purchase_order_id = 'YOUR_PO_ID_HERE'
AND gi.deleted = false
ORDER BY gi.created_at DESC, gii.item_id;
*/

-- Step 4: Calculate received quantities manually to verify
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID
/*
SELECT 
    poi.id as po_item_id,
    poi.item_id,
    poi.quantity as ordered_qty,
    poi.quantity_received as db_received_qty,
    COALESCE(SUM(gii.received_quantity), 0) as calculated_received_qty,
    (poi.quantity - COALESCE(SUM(gii.received_quantity), 0)) as calculated_remaining_qty,
    i.name as item_name,
    i.sku as item_sku
FROM purchase_order_items poi
LEFT JOIN inventory_items i ON i.id = poi.item_id
LEFT JOIN grn_inspections gi ON gi.purchase_order_id = poi.purchase_order_id 
    AND gi.deleted = false 
    AND gi.status IN ('approved', 'passed', 'pending')
LEFT JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id 
    AND gii.item_id = poi.item_id
WHERE poi.purchase_order_id = 'YOUR_PO_ID_HERE'
GROUP BY poi.id, poi.item_id, poi.quantity, poi.quantity_received, i.name, i.sku
ORDER BY poi.id;
*/

-- Step 5: Check if triggers are set up correctly
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND (event_object_table = 'grn_inspections' OR event_object_table = 'grn_inspection_items')
AND trigger_name LIKE '%po_quantities%'
ORDER BY event_object_table, trigger_name;

-- Step 6: Check if functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'update_po_received_quantities',
    'update_po_item_received_quantities',
    'calculate_po_received_quantities',
    'trigger_update_po_quantities',
    'trigger_update_po_quantities_from_item'
)
ORDER BY routine_name;

-- Step 7: Manually trigger update for a specific PO (for testing)
-- Replace 'YOUR_PO_ID_HERE' with your actual PO ID
/*
SELECT update_po_received_quantities('YOUR_PO_ID_HERE');
*/

-- Step 8: Check recent GRN status changes
SELECT 
    gi.id as grn_id,
    gi.grn_number,
    gi.status,
    gi.purchase_order_id,
    gi.updated_at,
    COUNT(gii.id) as items_count
FROM grn_inspections gi
LEFT JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
WHERE gi.deleted = false
GROUP BY gi.id, gi.grn_number, gi.status, gi.purchase_order_id, gi.updated_at
ORDER BY gi.updated_at DESC
LIMIT 10;


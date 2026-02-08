-- DEBUG SCRIPT: Check GRN Items in Database
-- Run this in Supabase SQL Editor to see if items are actually saved

-- 1. Check if grn_inspection_items table exists and has data
SELECT 
    'grn_inspection_items table check' as check_type,
    COUNT(*) as total_items,
    COUNT(DISTINCT grn_inspection_id) as total_grns_with_items
FROM grn_inspection_items;

-- 2. Check latest GRN items
SELECT 
    id,
    grn_inspection_id,
    item_id,
    item_code,
    item_name,
    ordered_quantity,
    received_quantity,
    unit_of_measure,
    created_at
FROM grn_inspection_items
ORDER BY created_at DESC
LIMIT 10;

-- 3. Check if items have item_id (foreign key to inventory_items)
SELECT 
    'Items with item_id' as check_type,
    COUNT(*) as count
FROM grn_inspection_items
WHERE item_id IS NOT NULL;

SELECT 
    'Items without item_id' as check_type,
    COUNT(*) as count
FROM grn_inspection_items
WHERE item_id IS NULL;

-- 4. Check latest GRN and its items
SELECT 
    g.id as grn_id,
    g.grn_number,
    g.status,
    g.purchase_order_id,
    COUNT(gi.id) as items_count
FROM grn_inspections g
LEFT JOIN grn_inspection_items gi ON gi.grn_inspection_id = g.id
WHERE g.deleted = false
GROUP BY g.id, g.grn_number, g.status, g.purchase_order_id
ORDER BY g.created_at DESC
LIMIT 5;

-- 5. Check if foreign key relationship works
SELECT 
    gi.id,
    gi.item_id,
    gi.item_name,
    gi.item_code,
    i.name as inventory_item_name,
    i.sku as inventory_item_sku
FROM grn_inspection_items gi
LEFT JOIN inventory_items i ON i.id = gi.item_id
ORDER BY gi.created_at DESC
LIMIT 10;


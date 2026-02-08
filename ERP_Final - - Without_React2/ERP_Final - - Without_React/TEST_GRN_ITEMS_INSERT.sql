-- TEST: Check if items can be inserted into grn_inspection_items
-- Run this in Supabase SQL Editor to test item insertion

-- First, get a GRN ID that has no items
SELECT 
    g.id as grn_id,
    g.grn_number,
    COUNT(gi.id) as items_count
FROM grn_inspections g
LEFT JOIN grn_inspection_items gi ON gi.grn_inspection_id = g.id
WHERE g.deleted = false
GROUP BY g.id, g.grn_number
HAVING COUNT(gi.id) = 0
ORDER BY g.created_at DESC
LIMIT 1;

-- Then try to insert a test item (replace 'YOUR_GRN_ID' with actual GRN ID from above)
-- Uncomment and run after getting GRN ID:
/*
INSERT INTO grn_inspection_items (
    grn_inspection_id,
    item_id,
    item_code,
    item_name,
    ordered_quantity,
    received_quantity,
    unit_of_measure
) VALUES (
    'YOUR_GRN_ID',  -- Replace with actual GRN ID
    NULL,  -- item_id can be NULL if item doesn't exist
    'TEST-ITEM-001',
    'Test Item',
    10.00,
    10.00,
    'Pcs'
) RETURNING *;
*/

-- Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'grn_inspection_items'
ORDER BY ordinal_position;


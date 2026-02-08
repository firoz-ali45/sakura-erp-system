-- QUICK FIX: Add missing columns to grn_inspection_items table
-- Run this in Supabase SQL Editor if items are not showing in GRN

-- Add ordered_quantity column (CRITICAL - this is why items are not showing!)
ALTER TABLE grn_inspection_items 
ADD COLUMN IF NOT EXISTS ordered_quantity NUMERIC(10, 2) DEFAULT 0;

-- Add purchase_order_id column (for linking items to PO)
ALTER TABLE grn_inspection_items 
ADD COLUMN IF NOT EXISTS purchase_order_id UUID;

-- Verify columns exist
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'grn_inspection_items'
AND column_name IN ('ordered_quantity', 'purchase_order_id', 'item_id', 'item_code', 'item_name')
ORDER BY column_name;


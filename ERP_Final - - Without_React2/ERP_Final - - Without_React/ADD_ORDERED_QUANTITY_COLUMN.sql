-- Add missing ordered_quantity column to grn_inspection_items table
-- Copy and paste ONLY this SQL into Supabase SQL Editor

ALTER TABLE grn_inspection_items 
ADD COLUMN IF NOT EXISTS ordered_quantity NUMERIC(10, 2) DEFAULT 0;

ALTER TABLE grn_inspection_items 
ADD COLUMN IF NOT EXISTS purchase_order_id UUID;


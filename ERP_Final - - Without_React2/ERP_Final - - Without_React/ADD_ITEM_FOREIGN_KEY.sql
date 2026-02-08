-- Add foreign key constraint for grn_inspection_items.item_id
-- This is CRITICAL for the item relationship query to work
-- Run this in Supabase SQL Editor

-- Check if inventory_items table exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='inventory_items' AND table_schema='public')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspection_items' AND column_name='item_id' AND table_schema='public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='grn_inspection_items_item_id_fkey' AND table_name='grn_inspection_items') THEN
        ALTER TABLE grn_inspection_items 
        ADD CONSTRAINT grn_inspection_items_item_id_fkey 
        FOREIGN KEY (item_id) REFERENCES inventory_items(id);
        RAISE NOTICE 'Foreign key constraint grn_inspection_items_item_id_fkey added successfully';
    ELSE
        RAISE NOTICE 'Foreign key constraint already exists or tables/columns missing';
    END IF;
END $$;


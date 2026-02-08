-- Update Inventory Items Table to add Inventory Item ID and Soft Delete
-- Run this SQL in Supabase SQL Editor

-- Add inventory_item_id column (unique identifier in SAK-FSID-00001 format)
ALTER TABLE inventory_items 
ADD COLUMN IF NOT EXISTS inventory_item_id TEXT UNIQUE;

-- Add deleted and deleted_at columns for soft delete
ALTER TABLE inventory_items 
ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Create index on inventory_item_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_inventory_items_item_id ON inventory_items(inventory_item_id);

-- Create index on deleted for faster filtering
CREATE INDEX IF NOT EXISTS idx_inventory_items_deleted ON inventory_items(deleted);

-- Update existing items to have inventory_item_id (if they don't have one)
-- This will generate IDs for existing items
DO $$
DECLARE
    item_record RECORD;
    counter INTEGER := 1;
BEGIN
    FOR item_record IN 
        SELECT id FROM inventory_items 
        WHERE inventory_item_id IS NULL 
        ORDER BY created_at ASC
    LOOP
        UPDATE inventory_items 
        SET inventory_item_id = 'SAK-FSID-' || LPAD(counter::TEXT, 5, '0')
        WHERE id = item_record.id;
        counter := counter + 1;
    END LOOP;
END $$;

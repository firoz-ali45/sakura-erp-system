-- Add supplier_lot_number column to grn_inspection_items table
-- This column stores the supplier lot number for each GRN item

DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='grn_inspection_items' AND table_schema='public') THEN
        -- Add supplier_lot_number column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='grn_inspection_items' 
            AND column_name='supplier_lot_number' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE grn_inspection_items 
            ADD COLUMN supplier_lot_number TEXT;
            
            RAISE NOTICE '✅ Added supplier_lot_number column to grn_inspection_items table';
        ELSE
            RAISE NOTICE 'ℹ️ supplier_lot_number column already exists in grn_inspection_items table';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ grn_inspection_items table does not exist. Please run CREATE_GRN_TABLES.sql first.';
    END IF;
END $$;


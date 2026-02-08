-- Fix PO Number NULL Constraint
-- This script allows po_number to be NULL for draft POs
-- Run this SQL in Supabase SQL Editor

DO $$
BEGIN
    -- Check if purchase_orders table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_orders' AND table_schema='public') THEN
        
        -- Step 1: Drop the UNIQUE constraint on po_number (if it exists)
        -- We'll recreate it as a partial unique index that allows NULL
        IF EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name='purchase_orders_po_number_key' 
            AND table_name='purchase_orders'
            AND table_schema='public'
        ) THEN
            ALTER TABLE purchase_orders DROP CONSTRAINT purchase_orders_po_number_key;
            RAISE NOTICE 'Dropped UNIQUE constraint on po_number';
        END IF;
        
        -- Step 2: Remove NOT NULL constraint from po_number
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='purchase_orders' 
            AND column_name='po_number' 
            AND table_schema='public'
            AND is_nullable='NO'
        ) THEN
            ALTER TABLE purchase_orders ALTER COLUMN po_number DROP NOT NULL;
            RAISE NOTICE 'Removed NOT NULL constraint from po_number - now allows NULL for draft POs';
        ELSE
            RAISE NOTICE 'po_number column already allows NULL values';
        END IF;
        
        -- Step 3: Create a partial unique index that only enforces uniqueness for non-NULL values
        -- This allows multiple NULL values (for drafts) but ensures uniqueness for actual PO numbers
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE indexname='idx_purchase_orders_po_number_unique' 
            AND tablename='purchase_orders'
        ) THEN
            CREATE UNIQUE INDEX idx_purchase_orders_po_number_unique 
            ON purchase_orders(po_number) 
            WHERE po_number IS NOT NULL;
            RAISE NOTICE 'Created partial unique index on po_number (allows multiple NULLs)';
        ELSE
            RAISE NOTICE 'Partial unique index on po_number already exists';
        END IF;
        
        RAISE NOTICE '✅ PO number constraint fixed successfully!';
        RAISE NOTICE '   - Draft POs can now have po_number = NULL';
        RAISE NOTICE '   - PO numbers will be unique when generated (after Submit for Review)';
        RAISE NOTICE '   - Multiple draft POs can coexist with NULL po_number';
        
    ELSE
        RAISE NOTICE '❌ Table purchase_orders does not exist. Please run CREATE_PURCHASE_ORDERS_TABLES.sql first.';
    END IF;
END $$;

-- Verify the changes
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'purchase_orders'
AND table_schema = 'public'
AND column_name = 'po_number';

-- Show the unique index
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'purchase_orders'
AND indexname = 'idx_purchase_orders_po_number_unique';

-- Fix GRN Number NULL Constraint
-- This script allows grn_number to be NULL for draft GRNs
-- Run this SQL in Supabase SQL Editor

DO $$
BEGIN
    -- Check if grn_inspections table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='grn_inspections' AND table_schema='public') THEN
        
        -- Step 1: Drop the UNIQUE constraint on grn_number (if it exists)
        -- We'll recreate it as a partial unique index that allows NULL
        IF EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name='grn_inspections_grn_number_key' 
            AND table_name='grn_inspections'
        ) THEN
            ALTER TABLE grn_inspections DROP CONSTRAINT grn_inspections_grn_number_key;
            RAISE NOTICE 'Dropped UNIQUE constraint on grn_number';
        END IF;
        
        -- Step 2: Remove NOT NULL constraint from grn_number
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='grn_inspections' 
            AND column_name='grn_number' 
            AND table_schema='public'
            AND is_nullable='NO'
        ) THEN
            ALTER TABLE grn_inspections ALTER COLUMN grn_number DROP NOT NULL;
            RAISE NOTICE 'Removed NOT NULL constraint from grn_number - now allows NULL for draft GRNs';
        ELSE
            RAISE NOTICE 'grn_number column already allows NULL values';
        END IF;
        
        -- Step 3: Create a partial unique index that only enforces uniqueness for non-NULL values
        -- This allows multiple NULL values (for drafts) but ensures uniqueness for actual GRN numbers
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE indexname='idx_grn_inspections_grn_number_unique' 
            AND tablename='grn_inspections'
        ) THEN
            CREATE UNIQUE INDEX idx_grn_inspections_grn_number_unique 
            ON grn_inspections(grn_number) 
            WHERE grn_number IS NOT NULL;
            RAISE NOTICE 'Created partial unique index on grn_number (allows multiple NULLs)';
        ELSE
            RAISE NOTICE 'Partial unique index on grn_number already exists';
        END IF;
        
        RAISE NOTICE '✅ GRN number constraint fixed successfully!';
        RAISE NOTICE '   - Draft GRNs can now have grn_number = NULL';
        RAISE NOTICE '   - GRN numbers will be unique when generated (after Submit for Inspection)';
        RAISE NOTICE '   - Multiple draft GRNs can coexist with NULL grn_number';
        
    ELSE
        RAISE NOTICE '❌ Table grn_inspections does not exist. Please run CREATE_GRN_TABLES.sql first.';
    END IF;
END $$;

-- Verify the changes
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'grn_inspections'
AND table_schema = 'public'
AND column_name = 'grn_number';

-- Show the unique index
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'grn_inspections'
AND indexname = 'idx_grn_inspections_grn_number_unique';

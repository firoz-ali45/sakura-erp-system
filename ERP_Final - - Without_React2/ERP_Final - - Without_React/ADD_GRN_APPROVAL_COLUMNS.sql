-- Add missing columns for GRN approval workflow
-- Run this SQL in Supabase SQL Editor

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='grn_inspections' AND table_schema='public') THEN
        -- Add submitted_for_approval column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='grn_inspections' 
            AND column_name='submitted_for_approval' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE grn_inspections ADD COLUMN submitted_for_approval BOOLEAN DEFAULT FALSE;
            RAISE NOTICE 'Added submitted_for_approval column to grn_inspections table';
        END IF;
        
        -- Add submitted_for_approval_at column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='grn_inspections' 
            AND column_name='submitted_for_approval_at' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE grn_inspections ADD COLUMN submitted_for_approval_at TIMESTAMP WITH TIME ZONE;
            RAISE NOTICE 'Added submitted_for_approval_at column to grn_inspections table';
        END IF;
        
        -- Add submitted_for_approval_by column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='grn_inspections' 
            AND column_name='submitted_for_approval_by' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE grn_inspections ADD COLUMN submitted_for_approval_by TEXT;
            RAISE NOTICE 'Added submitted_for_approval_by column to grn_inspections table';
        END IF;
        
        -- Ensure approved_by_name exists (might be missing)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='grn_inspections' 
            AND column_name='approved_by_name' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE grn_inspections ADD COLUMN approved_by_name TEXT;
            RAISE NOTICE 'Added approved_by_name column to grn_inspections table';
        END IF;
        
        -- Ensure approval_date exists (might be missing)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name='grn_inspections' 
            AND column_name='approval_date' 
            AND table_schema='public'
        ) THEN
            ALTER TABLE grn_inspections ADD COLUMN approval_date TIMESTAMP WITH TIME ZONE;
            RAISE NOTICE 'Added approval_date column to grn_inspections table';
        END IF;
        
        RAISE NOTICE 'All GRN approval workflow columns verified/added successfully';
    ELSE
        RAISE NOTICE 'Table grn_inspections does not exist. Please run CREATE_GRN_TABLES.sql first.';
    END IF;
END $$;

-- Verify columns were added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'grn_inspections'
AND table_schema = 'public'
AND column_name IN (
    'submitted_for_approval',
    'submitted_for_approval_at',
    'submitted_for_approval_by',
    'approved_by_name',
    'approval_date'
)
ORDER BY column_name;


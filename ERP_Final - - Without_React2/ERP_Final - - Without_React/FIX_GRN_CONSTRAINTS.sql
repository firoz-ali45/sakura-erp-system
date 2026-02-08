-- FIX GRN Constraints
-- Run this in Supabase SQL Editor to fix CHECK constraint violations

-- Step 1: Drop existing constraints that are too restrictive
DO $$ 
BEGIN
    -- Drop status constraint if it exists (will recreate with correct values)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'grn_inspections_status_check' 
        AND table_name = 'grn_inspections'
    ) THEN
        ALTER TABLE grn_inspections DROP CONSTRAINT grn_inspections_status_check;
        RAISE NOTICE 'Dropped grn_inspections_status_check constraint';
    END IF;
    
    -- Drop packaging_condition constraint if it exists (will recreate to allow NULL)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'grn_inspection_items_packaging_condition_check' 
        AND table_name = 'grn_inspection_items'
    ) THEN
        ALTER TABLE grn_inspection_items DROP CONSTRAINT grn_inspection_items_packaging_condition_check;
        RAISE NOTICE 'Dropped grn_inspection_items_packaging_condition_check constraint';
    END IF;
    
    -- Drop visual_inspection constraint if it exists (will recreate to allow NULL)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'grn_inspection_items_visual_inspection_check' 
        AND table_name = 'grn_inspection_items'
    ) THEN
        ALTER TABLE grn_inspection_items DROP CONSTRAINT grn_inspection_items_visual_inspection_check;
        RAISE NOTICE 'Dropped grn_inspection_items_visual_inspection_check constraint';
    END IF;
    
    -- Drop non_conformance_severity constraint if it exists (will recreate to allow NULL)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'grn_inspection_items_non_conformance_severity_check' 
        AND table_name = 'grn_inspection_items'
    ) THEN
        ALTER TABLE grn_inspection_items DROP CONSTRAINT grn_inspection_items_non_conformance_severity_check;
        RAISE NOTICE 'Dropped grn_inspection_items_non_conformance_severity_check constraint';
    END IF;
    
    -- Drop quality_status constraint if it exists (will recreate to allow NULL)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'grn_inspection_items_quality_status_check' 
        AND table_name = 'grn_inspection_items'
    ) THEN
        ALTER TABLE grn_inspection_items DROP CONSTRAINT grn_inspection_items_quality_status_check;
        RAISE NOTICE 'Dropped grn_inspection_items_quality_status_check constraint';
    END IF;
END $$;

-- Step 2: Recreate constraints with NULL allowed
-- Status constraint: Allow 'draft', 'pending', 'passed', 'hold', 'rejected', 'conditional'
ALTER TABLE grn_inspections 
ADD CONSTRAINT grn_inspections_status_check 
CHECK (status IS NULL OR status IN ('draft', 'pending', 'passed', 'hold', 'rejected', 'conditional'));

-- Packaging condition: Allow NULL, 'Good', or 'Damaged'
ALTER TABLE grn_inspection_items 
ADD CONSTRAINT grn_inspection_items_packaging_condition_check 
CHECK (packaging_condition IS NULL OR packaging_condition IN ('Good', 'Damaged'));

-- Visual inspection: Allow NULL, 'Pass', or 'Fail'
ALTER TABLE grn_inspection_items 
ADD CONSTRAINT grn_inspection_items_visual_inspection_check 
CHECK (visual_inspection IS NULL OR visual_inspection IN ('Pass', 'Fail'));

-- Non-conformance severity: Allow NULL, 'Critical', 'Major', or 'Minor'
ALTER TABLE grn_inspection_items 
ADD CONSTRAINT grn_inspection_items_non_conformance_severity_check 
CHECK (non_conformance_severity IS NULL OR non_conformance_severity IN ('Critical', 'Major', 'Minor'));

-- Quality status: Allow NULL, 'passed', 'failed', or 'conditional'
ALTER TABLE grn_inspection_items 
ADD CONSTRAINT grn_inspection_items_quality_status_check 
CHECK (quality_status IS NULL OR quality_status IN ('passed', 'failed', 'conditional'));

-- Verify constraints
SELECT 
    tc.constraint_name,
    tc.table_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name IN ('grn_inspections', 'grn_inspection_items')
AND tc.constraint_type = 'CHECK'
ORDER BY tc.table_name, tc.constraint_name;


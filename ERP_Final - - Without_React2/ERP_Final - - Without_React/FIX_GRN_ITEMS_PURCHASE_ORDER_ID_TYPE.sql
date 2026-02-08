-- Fix GRN Items purchase_order_id Type Mismatch
-- This script fixes the type mismatch between grn_inspections.purchase_order_id and grn_inspection_items.purchase_order_id
-- Run this in Supabase SQL Editor

-- Step 1: Check current types
SELECT 
  'grn_inspections' as table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'grn_inspections'
  AND column_name = 'purchase_order_id'
  AND table_schema = 'public'

UNION ALL

SELECT 
  'grn_inspection_items' as table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'grn_inspection_items'
  AND column_name = 'purchase_order_id'
  AND table_schema = 'public';

-- Step 2: Option A - Convert grn_inspection_items.purchase_order_id to match grn_inspections
-- (Only run this if grn_inspections.purchase_order_id is BIGINT and you want to match it)
DO $$
DECLARE
  grn_po_id_type TEXT;
  grn_item_po_id_type TEXT;
BEGIN
  SELECT data_type INTO grn_po_id_type
  FROM information_schema.columns
  WHERE table_name = 'grn_inspections'
    AND column_name = 'purchase_order_id'
    AND table_schema = 'public';
  
  SELECT data_type INTO grn_item_po_id_type
  FROM information_schema.columns
  WHERE table_name = 'grn_inspection_items'
    AND column_name = 'purchase_order_id'
    AND table_schema = 'public';
  
  RAISE NOTICE 'Current types: grn_inspections = %, grn_inspection_items = %', grn_po_id_type, grn_item_po_id_type;
  
  -- If grn_inspections is BIGINT and grn_inspection_items is UUID, convert to BIGINT
  IF grn_po_id_type IN ('bigint', 'integer', 'smallint') AND grn_item_po_id_type = 'uuid' THEN
    RAISE NOTICE '⚠️ Converting grn_inspection_items.purchase_order_id from UUID to BIGINT...';
    
    -- First, drop the column and recreate as BIGINT
    ALTER TABLE grn_inspection_items DROP COLUMN IF EXISTS purchase_order_id;
    ALTER TABLE grn_inspection_items ADD COLUMN purchase_order_id BIGINT;
    
    -- Update with values from grn_inspections
    UPDATE grn_inspection_items gii
    SET purchase_order_id = gi.purchase_order_id
    FROM grn_inspections gi
    WHERE gii.grn_inspection_id = gi.id
      AND gi.purchase_order_id IS NOT NULL;
    
    RAISE NOTICE '✅ Converted grn_inspection_items.purchase_order_id to BIGINT';
  ELSIF grn_po_id_type = 'uuid' AND grn_item_po_id_type IN ('bigint', 'integer', 'smallint') THEN
    RAISE NOTICE '⚠️ Converting grn_inspection_items.purchase_order_id from BIGINT to UUID...';
    
    -- First, drop the column and recreate as UUID
    ALTER TABLE grn_inspection_items DROP COLUMN IF EXISTS purchase_order_id;
    ALTER TABLE grn_inspection_items ADD COLUMN purchase_order_id UUID;
    
    -- Update with values from grn_inspections (direct assignment, both should be UUID now)
    UPDATE grn_inspection_items gii
    SET purchase_order_id = gi.purchase_order_id
    FROM grn_inspections gi
    WHERE gii.grn_inspection_id = gi.id
      AND gi.purchase_order_id IS NOT NULL;
    
    RAISE NOTICE '✅ Converted grn_inspection_items.purchase_order_id to UUID';
  ELSIF grn_po_id_type = grn_item_po_id_type THEN
    RAISE NOTICE '✅ Types already match: %', grn_po_id_type;
  ELSE
    RAISE NOTICE '⚠️ Unknown type combination. Please check manually.';
  END IF;
END $$;

-- Step 3: Verify types now match
SELECT 
  'grn_inspections' as table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'grn_inspections'
  AND column_name = 'purchase_order_id'
  AND table_schema = 'public'

UNION ALL

SELECT 
  'grn_inspection_items' as table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'grn_inspection_items'
  AND column_name = 'purchase_order_id'
  AND table_schema = 'public';

-- Step 4: Now update missing purchase_order_id values (should work now)
UPDATE grn_inspection_items gii
SET purchase_order_id = gi.purchase_order_id
FROM grn_inspections gi
WHERE gii.grn_inspection_id = gi.id
  AND gii.purchase_order_id IS NULL
  AND gi.purchase_order_id IS NOT NULL;

SELECT COUNT(*) as updated_count
FROM grn_inspection_items gii
INNER JOIN grn_inspections gi ON gii.grn_inspection_id = gi.id
WHERE gii.purchase_order_id IS NOT NULL
  AND gii.purchase_order_id = gi.purchase_order_id;


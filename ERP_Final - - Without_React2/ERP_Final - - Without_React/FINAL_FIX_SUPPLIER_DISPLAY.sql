-- Final Fix: Ensure supplier_name is properly populated in grn_inspections
-- Run this in Supabase SQL Editor to fix supplier display issue

-- Step 1: Check current state
SELECT 
  id,
  grn_number,
  supplier_id,
  supplier_name,
  purchase_order_id,
  purchase_order_number
FROM grn_inspections
WHERE deleted = false
  AND (supplier_name IS NULL OR supplier_name = '' OR supplier_name = 'N/A')
  AND supplier_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;

-- Step 2: Update supplier_name from suppliers table
UPDATE grn_inspections gi
SET supplier_name = s.name
FROM suppliers s
WHERE gi.supplier_id = s.id
  AND (gi.supplier_name IS NULL OR gi.supplier_name = '' OR gi.supplier_name = 'N/A')
  AND gi.deleted = false;

-- Step 3: Verify update
SELECT 
  COUNT(*) as total_grns,
  COUNT(CASE WHEN supplier_name IS NOT NULL AND supplier_name != '' AND supplier_name != 'N/A' THEN 1 END) as with_supplier_name,
  COUNT(CASE WHEN supplier_id IS NOT NULL THEN 1 END) as with_supplier_id
FROM grn_inspections
WHERE deleted = false;

-- Step 4: Show any remaining issues
SELECT 
  id,
  grn_number,
  supplier_id,
  supplier_name,
  CASE 
    WHEN supplier_id IS NOT NULL AND (supplier_name IS NULL OR supplier_name = '' OR supplier_name = 'N/A') 
    THEN 'NEEDS FIX'
    ELSE 'OK'
  END as status
FROM grn_inspections
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 20;


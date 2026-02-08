-- Fix Existing GRN Data: Update supplier_name and purchase_order_number
-- Run this SQL in Supabase SQL Editor to fix existing GRNs showing N/A
-- This will populate missing supplier_name and purchase_order_number from related tables

-- Step 1: Update purchase_order_number from purchase_orders table
UPDATE grn_inspections gi
SET purchase_order_number = po.po_number
FROM purchase_orders po
WHERE gi.purchase_order_id = po.id
  AND (gi.purchase_order_number IS NULL OR gi.purchase_order_number = '' OR gi.purchase_order_number = 'N/A');

-- Step 2: Update supplier_name from suppliers table
UPDATE grn_inspections gi
SET supplier_name = s.name
FROM suppliers s
WHERE gi.supplier_id = s.id
  AND (gi.supplier_name IS NULL OR gi.supplier_name = '' OR gi.supplier_name = 'N/A');

-- Step 3: If supplier_name is still null but supplier_id exists, try name_localized
UPDATE grn_inspections gi
SET supplier_name = s.name_localized
FROM suppliers s
WHERE gi.supplier_id = s.id
  AND gi.supplier_name IS NULL
  AND s.name_localized IS NOT NULL;

-- Step 4: Verify the updates
SELECT 
  COUNT(*) as total_grns,
  COUNT(CASE WHEN purchase_order_number IS NOT NULL AND purchase_order_number != '' AND purchase_order_number != 'N/A' THEN 1 END) as grns_with_po_number,
  COUNT(CASE WHEN supplier_name IS NOT NULL AND supplier_name != '' AND supplier_name != 'N/A' THEN 1 END) as grns_with_supplier_name
FROM grn_inspections
WHERE deleted = false;

-- Step 5: Show GRNs that still need fixing
SELECT 
  id,
  grn_number,
  purchase_order_id,
  purchase_order_number,
  supplier_id,
  supplier_name,
  status
FROM grn_inspections
WHERE deleted = false
  AND (
    (purchase_order_id IS NOT NULL AND (purchase_order_number IS NULL OR purchase_order_number = '' OR purchase_order_number = 'N/A'))
    OR
    (supplier_id IS NOT NULL AND (supplier_name IS NULL OR supplier_name = '' OR supplier_name = 'N/A'))
  )
ORDER BY created_at DESC;




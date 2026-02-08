-- Safe Version: Verify and Fix PO-GRN Integration
-- This version handles both UUID and INTEGER ID types
-- Run this SQL in Supabase SQL Editor

-- Step 1: Check if triggers are active
SELECT 
  trigger_name, 
  event_manipulation, 
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('grn_inspections', 'grn_inspection_items')
ORDER BY event_object_table, trigger_name;

-- Step 2: Check actual data types
SELECT 
  table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name IN ('purchase_orders', 'grn_inspections', 'grn_inspection_items')
  AND column_name IN ('id', 'purchase_order_id')
ORDER BY table_name, column_name;

-- Step 3: Check PO quantities for a specific PO (replace PO-000016 with your PO number)
SELECT 
  po.id,
  po.po_number,
  po.ordered_quantity,
  po.total_received_quantity,
  po.remaining_quantity,
  po.status,
  (SELECT COUNT(*) FROM grn_inspections WHERE purchase_order_id = po.id AND deleted = false) as grn_count,
  (SELECT SUM(gii.received_quantity) 
   FROM grn_inspections gi
   INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
   WHERE gi.purchase_order_id = po.id
   AND gi.status IN ('approved', 'passed', 'pending')
   AND gi.deleted = false) as calculated_received
FROM purchase_orders po
WHERE po.po_number = 'PO-000016'
LIMIT 1;

-- Step 4: Check GRNs for a specific PO
SELECT 
  gi.id,
  gi.grn_number,
  gi.purchase_order_id,
  gi.purchase_order_number,
  gi.supplier_id,
  gi.supplier_name,
  gi.status,
  (SELECT SUM(received_quantity) 
   FROM grn_inspection_items 
   WHERE grn_inspection_id = gi.id) as total_received
FROM grn_inspections gi
WHERE gi.purchase_order_number = 'PO-000016'
  OR gi.purchase_order_id IN (
    SELECT id FROM purchase_orders WHERE po_number = 'PO-000016'
  )
ORDER BY gi.created_at DESC;

-- Step 5: Manually trigger PO quantity update (SAFE VERSION - handles both UUID and INTEGER)
DO $$
DECLARE
  po_id_val TEXT;
  po_id_type TEXT;
  po_uuid UUID;
  po_int BIGINT;
BEGIN
  -- Check the actual data type
  SELECT data_type INTO po_id_type
  FROM information_schema.columns
  WHERE table_name = 'purchase_orders'
    AND column_name = 'id'
    AND table_schema = 'public';
  
  RAISE NOTICE '📊 Purchase Orders ID type: %', po_id_type;
  
  -- Get PO ID by PO number
  SELECT id::TEXT INTO po_id_val
  FROM purchase_orders
  WHERE po_number = 'PO-000016'
  LIMIT 1;
  
  IF po_id_val IS NOT NULL THEN
    RAISE NOTICE '✅ Found PO with ID: %', po_id_val;
    
    -- Try to call the function based on type
    IF po_id_type = 'uuid' THEN
      BEGIN
        po_uuid := po_id_val::UUID;
        PERFORM update_po_received_quantities(po_uuid);
        RAISE NOTICE '✅ PO quantities updated (UUID type)';
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Error updating PO (UUID): %', SQLERRM;
      END;
    ELSIF po_id_type IN ('integer', 'bigint', 'smallint') THEN
      RAISE NOTICE '⚠️ PO ID is INTEGER type. Function update_po_received_quantities expects UUID.';
      RAISE NOTICE '💡 Solution: You need to either:';
      RAISE NOTICE '   1. Convert purchase_orders.id to UUID type, OR';
      RAISE NOTICE '   2. Create an INTEGER version of update_po_received_quantities function';
      RAISE NOTICE '   3. Or manually update quantities using the queries below';
    ELSE
      RAISE NOTICE '⚠️ Unknown ID type: %. Attempting UUID conversion...', po_id_type;
      BEGIN
        po_uuid := po_id_val::UUID;
        PERFORM update_po_received_quantities(po_uuid);
        RAISE NOTICE '✅ PO quantities updated';
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Error: %', SQLERRM;
      END;
    END IF;
  ELSE
    RAISE NOTICE '❌ PO not found with number: PO-000016';
  END IF;
END $$;

-- Step 6: Manual PO quantity update (if function fails)
-- This works regardless of ID type
DO $$
DECLARE
  po_id_val TEXT;
  calculated_received NUMERIC(10, 2);
  calculated_ordered NUMERIC(10, 2);
BEGIN
  -- Get PO ID
  SELECT id::TEXT INTO po_id_val
  FROM purchase_orders
  WHERE po_number = 'PO-000016'
  LIMIT 1;
  
  IF po_id_val IS NOT NULL THEN
    -- Calculate received quantity
    SELECT COALESCE(SUM(gii.received_quantity), 0) INTO calculated_received
    FROM grn_inspections gi
    INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_id::TEXT = po_id_val
    AND gi.status IN ('approved', 'passed', 'pending')
    AND gi.deleted = false;
    
    -- Calculate ordered quantity
    SELECT COALESCE(SUM(poi.quantity), 0) INTO calculated_ordered
    FROM purchase_order_items poi
    WHERE poi.purchase_order_id::TEXT = po_id_val;
    
    -- Update PO quantities
    UPDATE purchase_orders
    SET 
      total_received_quantity = calculated_received,
      ordered_quantity = calculated_ordered,
      remaining_quantity = GREATEST(0, calculated_ordered - calculated_received),
      updated_at = NOW()
    WHERE id::TEXT = po_id_val;
    
    -- Auto-close if fully received
    UPDATE purchase_orders
    SET 
      status = 'closed',
      updated_at = NOW()
    WHERE id::TEXT = po_id_val
    AND status IN ('approved', 'partially_received')
    AND calculated_received >= calculated_ordered
    AND calculated_ordered > 0;
    
    RAISE NOTICE '✅ PO quantities manually updated:';
    RAISE NOTICE '   Ordered: %', calculated_ordered;
    RAISE NOTICE '   Received: %', calculated_received;
    RAISE NOTICE '   Remaining: %', GREATEST(0, calculated_ordered - calculated_received);
  END IF;
END $$;

-- Step 7: Check if GRN items have correct purchase_order_id
SELECT 
  gii.id,
  gii.grn_inspection_id,
  gii.purchase_order_id,
  gii.item_id,
  gii.received_quantity,
  gi.purchase_order_number,
  gi.status as grn_status
FROM grn_inspection_items gii
INNER JOIN grn_inspections gi ON gii.grn_inspection_id = gi.id
WHERE gi.purchase_order_number = 'PO-000016'
  OR gi.purchase_order_id::TEXT IN (
    SELECT id::TEXT FROM purchase_orders WHERE po_number = 'PO-000016'
  )
ORDER BY gii.created_at DESC;

-- Step 8: Fix GRN items missing purchase_order_id (if needed)
-- SAFE: Handles both UUID and BIGINT types
DO $$
DECLARE
  grn_po_id_type TEXT;
  grn_item_po_id_type TEXT;
BEGIN
  -- Check actual types
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
  
  RAISE NOTICE '📊 Types: grn_inspections.purchase_order_id = %, grn_inspection_items.purchase_order_id = %', 
    grn_po_id_type, grn_item_po_id_type;
  
  -- Update based on types
  IF grn_po_id_type = 'uuid' AND grn_item_po_id_type = 'uuid' THEN
    -- Both are UUID, direct assignment
    UPDATE grn_inspection_items gii
    SET purchase_order_id = gi.purchase_order_id
    FROM grn_inspections gi
    WHERE gii.grn_inspection_id = gi.id
      AND gii.purchase_order_id IS NULL
      AND gi.purchase_order_id IS NOT NULL;
    RAISE NOTICE '✅ Updated GRN items with purchase_order_id (UUID to UUID)';
  ELSIF grn_po_id_type IN ('bigint', 'integer', 'smallint') AND grn_item_po_id_type = 'uuid' THEN
    -- Source is BIGINT, target is UUID - cannot convert directly
    RAISE NOTICE '⚠️ Cannot convert BIGINT purchase_order_id to UUID. Skipping update.';
    RAISE NOTICE '💡 Solution: Either convert grn_inspections.purchase_order_id to UUID,';
    RAISE NOTICE '   OR convert grn_inspection_items.purchase_order_id to BIGINT.';
    RAISE NOTICE '   Or manually update using the query in Step 10.';
  ELSIF grn_po_id_type = 'uuid' AND grn_item_po_id_type IN ('bigint', 'integer', 'smallint') THEN
    -- Source is UUID, target is BIGINT - convert UUID to BIGINT (not recommended)
    RAISE NOTICE '⚠️ Converting UUID to BIGINT is not recommended. Skipping update.';
  ELSE
    -- Both are same type (BIGINT to BIGINT or INTEGER to INTEGER)
    UPDATE grn_inspection_items gii
    SET purchase_order_id = gi.purchase_order_id
    FROM grn_inspections gi
    WHERE gii.grn_inspection_id = gi.id
      AND gii.purchase_order_id IS NULL
      AND gi.purchase_order_id IS NOT NULL;
    RAISE NOTICE '✅ Updated GRN items with purchase_order_id (same type)';
  END IF;
END $$;

-- Step 9: Verify all GRNs have supplier_name and purchase_order_number
SELECT 
  COUNT(*) as total_grns,
  COUNT(CASE WHEN purchase_order_number IS NOT NULL AND purchase_order_number != '' AND purchase_order_number != 'N/A' THEN 1 END) as with_po_number,
  COUNT(CASE WHEN supplier_name IS NOT NULL AND supplier_name != '' AND supplier_name != 'N/A' THEN 1 END) as with_supplier_name,
  COUNT(CASE WHEN purchase_order_id IS NOT NULL THEN 1 END) as with_po_id
FROM grn_inspections
WHERE deleted = false;

-- Step 10: Show GRNs that need fixing
SELECT 
  id,
  grn_number,
  purchase_order_id,
  purchase_order_number,
  supplier_id,
  supplier_name,
  status,
  created_at
FROM grn_inspections
WHERE deleted = false
  AND (
    (purchase_order_id IS NOT NULL AND (purchase_order_number IS NULL OR purchase_order_number = '' OR purchase_order_number = 'N/A'))
    OR
    (supplier_id IS NOT NULL AND (supplier_name IS NULL OR supplier_name = '' OR supplier_name = 'N/A'))
  )
ORDER BY created_at DESC
LIMIT 20;

-- Step 10: Manual fix for GRN items purchase_order_id (if Step 8 fails due to type mismatch)
-- This handles type conversion properly
DO $$
DECLARE
  grn_po_id_type TEXT;
  grn_item_po_id_type TEXT;
  updated_count INTEGER;
BEGIN
  -- Check types
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
  
  RAISE NOTICE '📊 Checking types for manual fix: grn_inspections.purchase_order_id = %, grn_inspection_items.purchase_order_id = %', 
    grn_po_id_type, grn_item_po_id_type;
  
  -- If types match, do direct update
  IF grn_po_id_type = grn_item_po_id_type THEN
    UPDATE grn_inspection_items gii
    SET purchase_order_id = gi.purchase_order_id
    FROM grn_inspections gi
    WHERE gii.grn_inspection_id = gi.id
      AND gii.purchase_order_id IS NULL
      AND gi.purchase_order_id IS NOT NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Updated % GRN items with purchase_order_id (types match)', updated_count;
  ELSE
    RAISE NOTICE '⚠️ Type mismatch: Cannot automatically convert % to %', grn_po_id_type, grn_item_po_id_type;
    RAISE NOTICE '💡 To fix this permanently, you need to:';
    RAISE NOTICE '   1. Check your CREATE_GRN_TABLES.sql to ensure both columns use the same type';
    RAISE NOTICE '   2. Or manually update the schema to match types';
    RAISE NOTICE '   3. For now, GRN items will work without purchase_order_id (it''s optional)';
  END IF;
END $$;

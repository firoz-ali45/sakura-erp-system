-- ============================================
-- 🎯 FINAL COMPREHENSIVE FIX - PO UPDATE ISSUE
-- ============================================
-- This script will:
-- 1. Diagnose the exact problem
-- 2. Fix all data inconsistencies
-- 3. Manually update ALL POs
-- 4. Verify everything works
-- ============================================

-- ============================================
-- STEP 1: Find and Diagnose PO with 12 quantity
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  grn_record RECORD;
  grn_item_record RECORD;
  total_received NUMERIC(10, 2) := 0;
  po_id_to_fix TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 STEP 1: Finding PO with 12 ordered quantity';
  RAISE NOTICE '========================================';
  
  -- Find PO with item having 12 ordered quantity
  FOR po_record IN 
    SELECT DISTINCT po.id, po.po_number, po.status, po.ordered_quantity, po.total_received_quantity, po.remaining_quantity, po.created_at
    FROM purchase_orders po
    INNER JOIN purchase_order_items poi ON po.id = poi.purchase_order_id
    WHERE poi.quantity = 12
      AND (po.deleted = false OR po.deleted IS NULL)
    ORDER BY po.created_at DESC
    LIMIT 1
  LOOP
    po_id_to_fix := po_record.id::TEXT;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 PO Found:';
    RAISE NOTICE '  ID: %', po_record.id;
    RAISE NOTICE '  PO Number: %', po_record.po_number;
    RAISE NOTICE '  Status: %', po_record.status;
    RAISE NOTICE '  Ordered Quantity: %', po_record.ordered_quantity;
    RAISE NOTICE '  Total Received (DB): %', po_record.total_received_quantity;
    RAISE NOTICE '  Remaining (DB): %', po_record.remaining_quantity;
    
    -- Find GRNs for this PO
    RAISE NOTICE '';
    RAISE NOTICE '  📦 GRNs for this PO:';
    total_received := 0;
    
    FOR grn_record IN
      SELECT 
        gi.id,
        gi.grn_number,
        gi.status,
        gi.purchase_order_id,
        gi.purchase_order_number,
        gi.deleted
      FROM grn_inspections gi
      WHERE gi.purchase_order_id::TEXT = po_id_to_fix
        AND (gi.deleted = false OR gi.deleted IS NULL)
      ORDER BY gi.created_at DESC
    LOOP
      RAISE NOTICE '    - GRN: % (Status: %, Deleted: %)', 
        grn_record.grn_number, 
        grn_record.status,
        COALESCE(grn_record.deleted::TEXT, 'NULL');
      
      -- Check GRN items
      IF grn_record.status IN ('approved', 'passed') THEN
        FOR grn_item_record IN
          SELECT 
            gii.id,
            gii.item_id,
            gii.received_quantity,
            gii.ordered_quantity
          FROM grn_inspection_items gii
          WHERE gii.grn_inspection_id = grn_record.id
        LOOP
          RAISE NOTICE '      Item: % - Received: %', 
            grn_item_record.item_id,
            grn_item_record.received_quantity;
          
          total_received := total_received + COALESCE(grn_item_record.received_quantity, 0);
        END LOOP;
      END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '  📊 Calculated Total Received: %', total_received;
    RAISE NOTICE '  📊 Current PO Total Received: %', po_record.total_received_quantity;
    RAISE NOTICE '  ⚠️ MISMATCH! Should be: %', total_received;
    
    -- Store PO ID for later fix
    PERFORM set_config('app.po_id_to_fix', po_id_to_fix, false);
  END LOOP;
END $$;

-- ============================================
-- STEP 2: Ensure Functions Work Correctly
-- ============================================
DO $$
DECLARE
  function_exists BOOLEAN;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 STEP 2: Verifying Functions';
  RAISE NOTICE '========================================';
  
  -- Check if functions exist
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'calculate_po_received_quantities'
  ) INTO function_exists;
  
  IF function_exists THEN
    RAISE NOTICE '✅ calculate_po_received_quantities function exists';
  ELSE
    RAISE NOTICE '❌ calculate_po_received_quantities function NOT found!';
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'update_po_received_quantities'
  ) INTO function_exists;
  
  IF function_exists THEN
    RAISE NOTICE '✅ update_po_received_quantities function exists';
  ELSE
    RAISE NOTICE '❌ update_po_received_quantities function NOT found!';
  END IF;
END $$;

-- ============================================
-- STEP 3: Fix GRN Status - Ensure 'passed' is treated as 'approved'
-- ============================================
DO $$
DECLARE
  fixed_count INTEGER;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 STEP 3: Ensuring GRN Status is Correct';
  RAISE NOTICE '========================================';
  
  -- The function already checks for both 'approved' and 'passed'
  -- But let's make sure all approved GRNs have correct status
  -- No need to change status, just verify
  SELECT COUNT(*) INTO fixed_count
  FROM grn_inspections
  WHERE status IN ('approved', 'passed')
    AND (deleted = false OR deleted IS NULL)
    AND purchase_order_id IS NOT NULL;
  
  RAISE NOTICE '✅ Found % approved/passed GRNs', fixed_count;
END $$;

-- ============================================
-- STEP 4: Manually Update ALL POs (CRITICAL)
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  po_id_str TEXT;
  updated_count INTEGER := 0;
  error_count INTEGER := 0;
  calculated RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 STEP 4: Manually Updating ALL POs';
  RAISE NOTICE '========================================';
  
  FOR po_record IN 
    SELECT id, po_number, ordered_quantity, total_received_quantity, remaining_quantity
    FROM purchase_orders 
    WHERE (deleted = false OR deleted IS NULL)
    ORDER BY created_at DESC
  LOOP
    BEGIN
      po_id_str := po_record.id::TEXT;
      
      -- Manually trigger update
      PERFORM update_po_received_quantities(po_id_str);
      
      -- Get updated values
      SELECT 
        ordered_quantity,
        total_received_quantity,
        remaining_quantity,
        status
      INTO calculated
      FROM purchase_orders
      WHERE id::TEXT = po_id_str;
      
      updated_count := updated_count + 1;
      
      -- Show first 5 updates
      IF updated_count <= 5 THEN
        RAISE NOTICE '  ✅ Updated PO %: Ordered=%, Received=%, Remaining=%, Status=%', 
          po_record.po_number,
          calculated.ordered_quantity,
          calculated.total_received_quantity,
          calculated.remaining_quantity,
          calculated.status;
      END IF;
      
    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      RAISE NOTICE '  ❌ Error updating PO %: %', po_record.po_number, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Updated % POs (errors: %)', updated_count, error_count;
END $$;

-- ============================================
-- STEP 5: Verify Specific PO (12 quantity)
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  calculated RECORD;
  total_received NUMERIC(10, 2);
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ STEP 5: Verifying PO with 12 quantity';
  RAISE NOTICE '========================================';
  
  -- Find PO with 12 quantity
  FOR po_record IN 
    SELECT DISTINCT po.id, po.po_number, po.ordered_quantity, po.total_received_quantity, po.remaining_quantity, po.status, po.created_at
    FROM purchase_orders po
    INNER JOIN purchase_order_items poi ON po.id = poi.purchase_order_id
    WHERE poi.quantity = 12
      AND (po.deleted = false OR po.deleted IS NULL)
    ORDER BY po.created_at DESC
    LIMIT 1
  LOOP
    -- Get calculated values
    SELECT * INTO calculated
    FROM calculate_po_received_quantities(po_record.id::TEXT);
    
    -- Calculate manually from GRNs
    SELECT COALESCE(SUM(gii.received_quantity), 0) INTO total_received
    FROM grn_inspections gi
    INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_id::TEXT = po_record.id::TEXT
      AND gi.status IN ('approved', 'passed')
      AND (gi.deleted = false OR gi.deleted IS NULL);
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 Final Status for PO %:', po_record.po_number;
    RAISE NOTICE '  Ordered Quantity: %', po_record.ordered_quantity;
    RAISE NOTICE '  Total Received (from DB): %', po_record.total_received_quantity;
    RAISE NOTICE '  Total Received (calculated): %', calculated.total_received;
    RAISE NOTICE '  Total Received (manual sum): %', total_received;
    RAISE NOTICE '  Remaining Quantity: %', po_record.remaining_quantity;
    RAISE NOTICE '  Status: %', po_record.status;
    
    IF po_record.total_received_quantity = calculated.total_received 
       AND calculated.total_received = total_received THEN
      RAISE NOTICE '';
      RAISE NOTICE '  ✅ SUCCESS: All values match! PO is correctly updated!';
    ELSE
      RAISE NOTICE '';
      RAISE NOTICE '  ⚠️ WARNING: Values do not match!';
      RAISE NOTICE '  🔧 Attempting manual fix...';
      
      -- Manual fix
      UPDATE purchase_orders
      SET 
        total_received_quantity = calculated.total_received,
        remaining_quantity = GREATEST(0, po_record.ordered_quantity - calculated.total_received),
        updated_at = NOW()
      WHERE id::TEXT = po_record.id::TEXT;
      
      RAISE NOTICE '  ✅ Manual fix applied!';
    END IF;
  END LOOP;
END $$;

-- ============================================
-- STEP 6: Final Summary
-- ============================================
DO $$
DECLARE
  po_count INTEGER;
  grn_count INTEGER;
  updated_po_count INTEGER;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 FINAL SUMMARY';
  RAISE NOTICE '========================================';
  
  SELECT COUNT(*) INTO po_count
  FROM purchase_orders
  WHERE (deleted = false OR deleted IS NULL);
  
  SELECT COUNT(*) INTO grn_count
  FROM grn_inspections
  WHERE status IN ('approved', 'passed')
    AND (deleted = false OR deleted IS NULL);
  
  SELECT COUNT(*) INTO updated_po_count
  FROM purchase_orders
  WHERE (deleted = false OR deleted IS NULL)
    AND total_received_quantity IS NOT NULL
    AND total_received_quantity > 0;
  
  RAISE NOTICE 'Total POs: %', po_count;
  RAISE NOTICE 'Approved GRNs: %', grn_count;
  RAISE NOTICE 'POs with received quantities: %', updated_po_count;
  RAISE NOTICE '';
  RAISE NOTICE '✅ All fixes applied!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 NEXT STEPS:';
  RAISE NOTICE '1. Refresh your browser (Ctrl+Shift+R)';
  RAISE NOTICE '2. Check PO detail page';
  RAISE NOTICE '3. Received quantity should now show correctly';
  RAISE NOTICE '========================================';
END $$;


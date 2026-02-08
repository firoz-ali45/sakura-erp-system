-- ============================================
-- 🔍 DEBUG AND FIX PO UPDATE ISSUE
-- ============================================
-- This script will:
-- 1. Check if GRN is properly linked to PO
-- 2. Check GRN status and items
-- 3. Manually trigger PO update
-- 4. Fix any data inconsistencies
-- ============================================

-- ============================================
-- STEP 1: Find PO with 12 ordered quantity
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  grn_record RECORD;
  grn_item_record RECORD;
  total_received NUMERIC(10, 2) := 0;
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
    LIMIT 5
  LOOP
    RAISE NOTICE '';
    RAISE NOTICE '📋 PO Found:';
    RAISE NOTICE '  ID: %', po_record.id;
    RAISE NOTICE '  PO Number: %', po_record.po_number;
    RAISE NOTICE '  Status: %', po_record.status;
    RAISE NOTICE '  Ordered Quantity: %', po_record.ordered_quantity;
    RAISE NOTICE '  Total Received: %', po_record.total_received_quantity;
    RAISE NOTICE '  Remaining: %', po_record.remaining_quantity;
    
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
      WHERE gi.purchase_order_id = po_record.id
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
            gii.ordered_quantity,
            poi.quantity as po_item_quantity
          FROM grn_inspection_items gii
          LEFT JOIN purchase_order_items poi ON gii.item_id = poi.item_id 
            AND poi.purchase_order_id = po_record.id
          WHERE gii.grn_inspection_id = grn_record.id
        LOOP
          RAISE NOTICE '      Item: % - Received: %, Ordered: %, PO Item Qty: %', 
            grn_item_record.item_id,
            grn_item_record.received_quantity,
            grn_item_record.ordered_quantity,
            grn_item_record.po_item_quantity;
          
          total_received := total_received + COALESCE(grn_item_record.received_quantity, 0);
        END LOOP;
      END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '  📊 Calculated Total Received: %', total_received;
    RAISE NOTICE '  📊 Current PO Total Received: %', po_record.total_received_quantity;
    RAISE NOTICE '  ⚠️ Should be: %', total_received;
    
    -- Check if update is needed
    IF total_received != COALESCE(po_record.total_received_quantity, 0) THEN
      RAISE NOTICE '  ❌ MISMATCH DETECTED! PO needs update.';
    ELSE
      RAISE NOTICE '  ✅ Quantities match.';
    END IF;
  END LOOP;
END $$;

-- ============================================
-- STEP 2: Check Trigger Status
-- ============================================
DO $$
DECLARE
  trigger_count INTEGER;
  trigger_record RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 STEP 2: Checking Trigger Status';
  RAISE NOTICE '========================================';
  
  SELECT COUNT(*) INTO trigger_count
  FROM information_schema.triggers
  WHERE trigger_name LIKE 'trg_grn%po_quantities%';
  
  RAISE NOTICE 'Total PO update triggers: %', trigger_count;
  
  IF trigger_count < 6 THEN
    RAISE NOTICE '⚠️ WARNING: Expected 6 triggers, found %', trigger_count;
  END IF;
  
  FOR trigger_record IN
    SELECT trigger_name, event_object_table, action_timing, event_manipulation
    FROM information_schema.triggers
    WHERE trigger_name LIKE 'trg_grn%po_quantities%'
    ORDER BY trigger_name
  LOOP
    RAISE NOTICE '  ✅ % on % (% %)', 
      trigger_record.trigger_name,
      trigger_record.event_object_table,
      trigger_record.action_timing,
      trigger_record.event_manipulation;
  END LOOP;
END $$;

-- ============================================
-- STEP 3: Manually Update ALL POs
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  po_id_str TEXT;
  updated_count INTEGER := 0;
  error_count INTEGER := 0;
  error_msg TEXT;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 STEP 3: Manually Updating ALL POs';
  RAISE NOTICE '========================================';
  
  FOR po_record IN 
    SELECT id, po_number 
    FROM purchase_orders 
    WHERE (deleted = false OR deleted IS NULL)
    ORDER BY created_at DESC
  LOOP
    BEGIN
      po_id_str := po_record.id::TEXT;
      PERFORM update_po_received_quantities(po_id_str);
      updated_count := updated_count + 1;
      
      -- Get updated values
      DECLARE
        updated_po RECORD;
      BEGIN
        SELECT 
          ordered_quantity,
          total_received_quantity,
          remaining_quantity,
          status
        INTO updated_po
        FROM purchase_orders
        WHERE id::TEXT = po_id_str;
        
        IF updated_count <= 5 THEN
          RAISE NOTICE '  ✅ Updated PO %: Ordered=%, Received=%, Remaining=%, Status=%', 
            po_record.po_number,
            updated_po.ordered_quantity,
            updated_po.total_received_quantity,
            updated_po.remaining_quantity,
            updated_po.status;
        END IF;
      END;
      
    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      error_msg := SQLERRM;
      RAISE NOTICE '  ❌ Error updating PO %: %', po_record.po_number, error_msg;
    END;
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Updated % POs (errors: %)', updated_count, error_count;
END $$;

-- ============================================
-- STEP 4: Fix GRN Status Issues
-- ============================================
DO $$
DECLARE
  fixed_count INTEGER;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 STEP 4: Fixing GRN Status Issues';
  RAISE NOTICE '========================================';
  
  -- Check for GRNs with 'approved' status but not triggering updates
  -- Ensure all approved GRNs have correct status
  UPDATE grn_inspections
  SET status = 'approved'
  WHERE status IN ('passed', 'approved')
    AND (deleted = false OR deleted IS NULL)
    AND purchase_order_id IS NOT NULL;
  
  GET DIAGNOSTICS fixed_count = ROW_COUNT;
  RAISE NOTICE '✅ Ensured % GRNs have correct status', fixed_count;
END $$;

-- ============================================
-- STEP 5: Fix Missing purchase_order_id in GRN Items
-- ============================================
DO $$
DECLARE
  fixed_count INTEGER;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 STEP 5: Fixing Missing purchase_order_id in GRN Items';
  RAISE NOTICE '========================================';
  
  -- Update grn_inspection_items to have purchase_order_id from parent GRN
  UPDATE grn_inspection_items gii
  SET purchase_order_id = gi.purchase_order_id
  FROM grn_inspections gi
  WHERE gii.grn_inspection_id = gi.id
    AND gii.purchase_order_id IS NULL
    AND gi.purchase_order_id IS NOT NULL;
  
  GET DIAGNOSTICS fixed_count = ROW_COUNT;
  RAISE NOTICE '✅ Fixed % GRN items with missing purchase_order_id', fixed_count;
END $$;

-- ============================================
-- STEP 6: Re-trigger Updates for Specific PO
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  po_id_str TEXT;
  result RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔧 STEP 6: Re-triggering Updates for PO with 12 quantity';
  RAISE NOTICE '========================================';
  
  -- Find and update PO with 12 quantity
  FOR po_record IN 
    SELECT DISTINCT po.id, po.po_number, po.created_at
    FROM purchase_orders po
    INNER JOIN purchase_order_items poi ON po.id = poi.purchase_order_id
    WHERE poi.quantity = 12
      AND (po.deleted = false OR po.deleted IS NULL)
    ORDER BY po.created_at DESC
    LIMIT 1
  LOOP
    po_id_str := po_record.id::TEXT;
    
    RAISE NOTICE 'Found PO: % (ID: %)', po_record.po_number, po_id_str;
    
    -- Manually trigger update
    PERFORM update_po_received_quantities(po_id_str);
    
    -- Get result
    SELECT 
      ordered_quantity,
      total_received_quantity,
      remaining_quantity,
      status
    INTO result
    FROM purchase_orders
    WHERE id::TEXT = po_id_str;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Updated PO Quantities:';
    RAISE NOTICE '  Ordered: %', result.ordered_quantity;
    RAISE NOTICE '  Received: %', result.total_received_quantity;
    RAISE NOTICE '  Remaining: %', result.remaining_quantity;
    RAISE NOTICE '  Status: %', result.status;
    
    -- Verify calculation
    DECLARE
      calculated RECORD;
    BEGIN
      SELECT * INTO calculated
      FROM calculate_po_received_quantities(po_id_str);
      
      RAISE NOTICE '';
      RAISE NOTICE '🔍 Verification:';
      RAISE NOTICE '  Calculated Received: %', calculated.total_received;
      RAISE NOTICE '  Calculated Ordered: %', calculated.ordered_qty;
      
      IF calculated.total_received != result.total_received_quantity THEN
        RAISE NOTICE '  ⚠️ WARNING: Calculated value differs from stored value!';
      ELSE
        RAISE NOTICE '  ✅ Calculated values match stored values.';
      END IF;
    END;
  END LOOP;
END $$;

-- ============================================
-- STEP 7: Final Verification
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  grn_count INTEGER;
  total_received NUMERIC(10, 2);
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ STEP 7: Final Verification';
  RAISE NOTICE '========================================';
  
  -- Check PO with 12 quantity
  FOR po_record IN 
    SELECT DISTINCT po.id, po.po_number, po.ordered_quantity, po.total_received_quantity, po.remaining_quantity, po.created_at
    FROM purchase_orders po
    INNER JOIN purchase_order_items poi ON po.id = poi.purchase_order_id
    WHERE poi.quantity = 12
      AND (po.deleted = false OR po.deleted IS NULL)
    ORDER BY po.created_at DESC
    LIMIT 1
  LOOP
    -- Count approved GRNs
    SELECT COUNT(*) INTO grn_count
    FROM grn_inspections
    WHERE purchase_order_id = po_record.id
      AND status IN ('approved', 'passed')
      AND (deleted = false OR deleted IS NULL);
    
    -- Calculate total received
    SELECT COALESCE(SUM(gii.received_quantity), 0) INTO total_received
    FROM grn_inspections gi
    INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_id = po_record.id
      AND gi.status IN ('approved', 'passed')
      AND (gi.deleted = false OR gi.deleted IS NULL);
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 Final Status for PO %:', po_record.po_number;
    RAISE NOTICE '  Ordered Quantity: %', po_record.ordered_quantity;
    RAISE NOTICE '  Total Received (from DB): %', po_record.total_received_quantity;
    RAISE NOTICE '  Total Received (calculated): %', total_received;
    RAISE NOTICE '  Remaining Quantity: %', po_record.remaining_quantity;
    RAISE NOTICE '  Approved GRNs: %', grn_count;
    
    IF po_record.total_received_quantity = total_received THEN
      RAISE NOTICE '';
      RAISE NOTICE '  ✅ SUCCESS: PO quantities are correct!';
    ELSE
      RAISE NOTICE '';
      RAISE NOTICE '  ❌ ERROR: PO quantities do not match calculated values!';
      RAISE NOTICE '  🔧 Try running this script again or check GRN data.';
    END IF;
  END LOOP;
END $$;

-- Final completion message
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Debug and Fix Script Complete!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📝 NEXT STEPS:';
  RAISE NOTICE '1. Check the output above for any errors';
  RAISE NOTICE '2. Refresh your browser (Ctrl+Shift+R)';
  RAISE NOTICE '3. Check PO detail page - quantities should be updated';
  RAISE NOTICE '4. If still not working, check console for errors';
  RAISE NOTICE '========================================';
END $$;


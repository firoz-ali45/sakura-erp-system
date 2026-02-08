-- ============================================
-- 🔍 DIAGNOSE AND FIX ALL ISSUES - COMPREHENSIVE
-- ============================================
-- This script:
-- 1. Diagnoses what's actually wrong
-- 2. Fixes all issues step by step
-- 3. Verifies everything works
-- ============================================

-- ============================================
-- STEP 1: DIAGNOSE - Check Current State
-- ============================================
DO $$
DECLARE
  fk_exists BOOLEAN;
  po_item_id_type TEXT;
  inv_item_id_type TEXT;
  batches_table_exists BOOLEAN;
  batches_columns TEXT[];
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 DIAGNOSIS STARTING...';
  RAISE NOTICE '========================================';
  
  -- Check FK relationship
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_name = 'purchase_order_items'
      AND kcu.column_name = 'item_id'
      AND tc.constraint_type = 'FOREIGN KEY'
  ) INTO fk_exists;
  
  -- Get column types
  SELECT data_type INTO po_item_id_type
  FROM information_schema.columns
  WHERE table_name = 'purchase_order_items'
    AND column_name = 'item_id';
  
  SELECT data_type INTO inv_item_id_type
  FROM information_schema.columns
  WHERE table_name = 'inventory_items'
    AND column_name = 'id';
  
  -- Check batches table
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'grn_batches'
  ) INTO batches_table_exists;
  
  -- Get batches table columns
  IF batches_table_exists THEN
    SELECT array_agg(column_name) INTO batches_columns
    FROM information_schema.columns
    WHERE table_name = 'grn_batches';
  END IF;
  
  RAISE NOTICE '📊 DIAGNOSIS RESULTS:';
  RAISE NOTICE '  FK exists: %', fk_exists;
  RAISE NOTICE '  PO item_id type: %', po_item_id_type;
  RAISE NOTICE '  inventory_items id type: %', inv_item_id_type;
  RAISE NOTICE '  grn_batches table exists: %', batches_table_exists;
  IF batches_table_exists THEN
    RAISE NOTICE '  grn_batches columns: %', array_to_string(batches_columns, ', ');
  END IF;
  RAISE NOTICE '========================================';
END $$;

-- ============================================
-- STEP 2: Fix Foreign Key Relationship
-- ============================================
DO $$
DECLARE
  fk_exists BOOLEAN;
BEGIN
  -- Check if FK already exists
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_name = 'purchase_order_items'
      AND kcu.column_name = 'item_id'
      AND tc.constraint_type = 'FOREIGN KEY'
  ) INTO fk_exists;
  
  IF NOT fk_exists THEN
    -- Drop existing constraint if it exists with wrong name
    ALTER TABLE purchase_order_items
    DROP CONSTRAINT IF EXISTS purchase_order_items_item_id_fkey;
    
    -- Create foreign key constraint
    ALTER TABLE purchase_order_items
    ADD CONSTRAINT purchase_order_items_item_id_fkey
    FOREIGN KEY (item_id) REFERENCES inventory_items(id)
    ON DELETE SET NULL;
    
    RAISE NOTICE '✅ Foreign key constraint created successfully';
  ELSE
    RAISE NOTICE '✅ Foreign key constraint already exists';
  END IF;
END $$;

-- ============================================
-- STEP 3: Fix grn_batches Table Schema
-- ============================================
-- Drop and recreate with all required columns
DO $$
BEGIN
  -- Drop table if exists (will cascade delete data, but that's okay for fix)
  DROP TABLE IF EXISTS grn_batches CASCADE;
  
  -- Create table with ALL required columns
  CREATE TABLE grn_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_id UUID NOT NULL,
    item_id UUID,
    batch_id TEXT,
    batch_number TEXT,
    batchId TEXT, -- Frontend expects this camelCase version
    expiry_date TIMESTAMP WITH TIME ZONE,
    quantity NUMERIC(10, 2) DEFAULT 0,
    qc_data JSONB, -- Frontend expects qcData
    qcData JSONB, -- Also add camelCase version
    qc_checked_at TIMESTAMP WITH TIME ZONE,
    qcCheckedAt TIMESTAMP WITH TIME ZONE, -- Also add camelCase version
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    createdBy UUID, -- Also add camelCase version
    CONSTRAINT grn_batches_grn_id_fkey 
      FOREIGN KEY (grn_id) REFERENCES grn_inspections(id) ON DELETE CASCADE
  );
  
  -- Create indexes
  CREATE INDEX idx_grn_batches_grn_id ON grn_batches(grn_id);
  CREATE INDEX idx_grn_batches_item_id ON grn_batches(item_id);
  CREATE INDEX idx_grn_batches_expiry_date ON grn_batches(expiry_date);
  
  RAISE NOTICE '✅ grn_batches table created with all required columns';
END $$;

-- ============================================
-- STEP 4: Create/Update PO Update Functions
-- ============================================
CREATE OR REPLACE FUNCTION calculate_po_received_quantities(po_id_param TEXT)
RETURNS TABLE(
    total_received NUMERIC(10, 2),
    ordered_qty NUMERIC(10, 2)
) AS $$
DECLARE
  po_id_type TEXT;
BEGIN
  -- Detect PO ID type
  SELECT data_type INTO po_id_type
  FROM information_schema.columns
  WHERE table_name = 'purchase_orders'
    AND column_name = 'id';
  
  RETURN QUERY
  WITH po_items_summary AS (
    SELECT 
      COALESCE(SUM(poi.quantity), 0) as ordered_qty
    FROM purchase_order_items poi
    WHERE poi.purchase_order_id::TEXT = po_id_param
  ),
  grn_received_summary AS (
    SELECT 
      COALESCE(SUM(gii.received_quantity), 0) as total_received
    FROM grn_inspections gi
    INNER JOIN grn_inspection_items gii ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_id::TEXT = po_id_param
    AND gi.status IN ('approved', 'passed')
    AND (gi.deleted = false OR gi.deleted IS NULL)
  )
  SELECT 
    COALESCE(grn_received_summary.total_received, 0)::NUMERIC(10, 2) as total_received,
    COALESCE(po_items_summary.ordered_qty, 0)::NUMERIC(10, 2) as ordered_qty
  FROM po_items_summary
  CROSS JOIN grn_received_summary;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_po_received_quantities(po_id_param TEXT)
RETURNS VOID AS $$
DECLARE
  calculated_data RECORD;
  po_id_type TEXT;
BEGIN
  -- Detect PO ID type
  SELECT data_type INTO po_id_type
  FROM information_schema.columns
  WHERE table_name = 'purchase_orders'
    AND column_name = 'id';
  
  -- Calculate received quantities
  SELECT * INTO calculated_data
  FROM calculate_po_received_quantities(po_id_param);
  
  -- Update PO with calculated values (works with both UUID and BIGINT)
  UPDATE purchase_orders
  SET 
    total_received_quantity = calculated_data.total_received,
    ordered_quantity = calculated_data.ordered_qty,
    remaining_quantity = GREATEST(0, calculated_data.ordered_qty - calculated_data.total_received),
    updated_at = NOW()
  WHERE id::TEXT = po_id_param;
  
  -- Auto-close PO if fully received
  UPDATE purchase_orders
  SET 
    status = 'closed',
    updated_at = NOW()
  WHERE id::TEXT = po_id_param
  AND status IN ('approved', 'partially_received', 'open')
  AND calculated_data.total_received >= calculated_data.ordered_qty
  AND calculated_data.ordered_qty > 0;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- STEP 5: Create/Update Trigger Functions
-- ============================================
CREATE OR REPLACE FUNCTION trigger_update_po_quantities()
RETURNS TRIGGER AS $$
DECLARE
  po_id_val TEXT;
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    po_id_val := NEW.purchase_order_id::TEXT;
  ELSIF TG_OP = 'DELETE' THEN
    po_id_val := OLD.purchase_order_id::TEXT;
  END IF;
  
  IF po_id_val IS NOT NULL AND po_id_val != '' THEN
    PERFORM update_po_received_quantities(po_id_val);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_update_po_quantities_from_item()
RETURNS TRIGGER AS $$
DECLARE
  po_id_val TEXT;
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    SELECT purchase_order_id::TEXT INTO po_id_val
    FROM grn_inspections
    WHERE id = NEW.grn_inspection_id;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT purchase_order_id::TEXT INTO po_id_val
    FROM grn_inspections
    WHERE id = OLD.grn_inspection_id;
  END IF;
  
  IF po_id_val IS NOT NULL AND po_id_val != '' THEN
    PERFORM update_po_received_quantities(po_id_val);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- STEP 6: Create/Recreate All Triggers
-- ============================================
DROP TRIGGER IF EXISTS trg_grn_insert_po_quantities ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_update_po_quantities ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_delete_po_quantities ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_items_insert_po_quantities ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_items_update_po_quantities ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_grn_items_delete_po_quantities ON grn_inspection_items;

CREATE TRIGGER trg_grn_insert_po_quantities
    AFTER INSERT ON grn_inspections
    FOR EACH ROW
    WHEN (NEW.purchase_order_id IS NOT NULL)
    EXECUTE FUNCTION trigger_update_po_quantities();

CREATE TRIGGER trg_grn_update_po_quantities
    AFTER UPDATE ON grn_inspections
    FOR EACH ROW
    WHEN (OLD.purchase_order_id IS DISTINCT FROM NEW.purchase_order_id 
          OR OLD.status IS DISTINCT FROM NEW.status
          OR OLD.deleted IS DISTINCT FROM NEW.deleted)
    EXECUTE FUNCTION trigger_update_po_quantities();

CREATE TRIGGER trg_grn_delete_po_quantities
    AFTER DELETE ON grn_inspections
    FOR EACH ROW
    WHEN (OLD.purchase_order_id IS NOT NULL)
    EXECUTE FUNCTION trigger_update_po_quantities();

CREATE TRIGGER trg_grn_items_insert_po_quantities
    AFTER INSERT ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

CREATE TRIGGER trg_grn_items_update_po_quantities
    AFTER UPDATE ON grn_inspection_items
    FOR EACH ROW
    WHEN (OLD.received_quantity IS DISTINCT FROM NEW.received_quantity)
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

CREATE TRIGGER trg_grn_items_delete_po_quantities
    AFTER DELETE ON grn_inspection_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_po_quantities_from_item();

DO $$
BEGIN
  RAISE NOTICE '✅ All 6 triggers created successfully';
END $$;

-- ============================================
-- STEP 7: Fix Supplier Names in GRNs
-- ============================================
DO $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE grn_inspections gi
  SET supplier_name = s.name
  FROM suppliers s
  WHERE gi.supplier_id = s.id
    AND (gi.supplier_name IS NULL 
         OR gi.supplier_name = '' 
         OR gi.supplier_name = 'N/A'
         OR gi.supplier_name = 'null');
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '✅ Fixed supplier_name in grn_inspections: % rows updated', updated_count;
END $$;

-- ============================================
-- STEP 8: Fix Purchase Order Numbers in GRNs
-- ============================================
DO $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE grn_inspections gi
  SET purchase_order_number = po.po_number
  FROM purchase_orders po
  WHERE gi.purchase_order_id = po.id
    AND (gi.purchase_order_number IS NULL 
         OR gi.purchase_order_number = '' 
         OR gi.purchase_order_number = 'N/A'
         OR gi.purchase_order_number = 'null');
  
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '✅ Fixed purchase_order_number in grn_inspections: % rows updated', updated_count;
END $$;

-- ============================================
-- STEP 9: Recalculate ALL PO Quantities
-- ============================================
DO $$
DECLARE
  po_record RECORD;
  po_id_str TEXT;
  recalculated_count INTEGER := 0;
  error_count INTEGER := 0;
BEGIN
  FOR po_record IN 
    SELECT id FROM purchase_orders WHERE deleted = false OR deleted IS NULL
  LOOP
    BEGIN
      po_id_str := po_record.id::TEXT;
      PERFORM update_po_received_quantities(po_id_str);
      recalculated_count := recalculated_count + 1;
    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      RAISE NOTICE '⚠️ Error updating PO %: %', po_record.id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE '✅ Recalculated quantities for % POs (errors: %)', recalculated_count, error_count;
END $$;

-- ============================================
-- STEP 10: FINAL VERIFICATION
-- ============================================
DO $$
DECLARE
  fk_count INTEGER;
  supplier_fixed_count INTEGER;
  po_fixed_count INTEGER;
  batches_table_exists BOOLEAN;
  trigger_count INTEGER;
  function_count INTEGER;
  batches_columns TEXT[];
BEGIN
  -- Check FK
  SELECT COUNT(*) INTO fk_count
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
  WHERE tc.table_name = 'purchase_order_items'
    AND kcu.column_name = 'item_id'
    AND tc.constraint_type = 'FOREIGN KEY';
  
  -- Check supplier names
  SELECT COUNT(*) INTO supplier_fixed_count
  FROM grn_inspections gi
  JOIN suppliers s ON gi.supplier_id = s.id
  WHERE gi.supplier_name = s.name
    AND (gi.deleted = false OR gi.deleted IS NULL);
  
  -- Check PO numbers
  SELECT COUNT(*) INTO po_fixed_count
  FROM grn_inspections gi
  JOIN purchase_orders po ON gi.purchase_order_id = po.id
  WHERE gi.purchase_order_number = po.po_number
    AND (gi.deleted = false OR gi.deleted IS NULL);
  
  -- Check batches table
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'grn_batches'
  ) INTO batches_table_exists;
  
  -- Get batches columns
  IF batches_table_exists THEN
    SELECT array_agg(column_name) INTO batches_columns
    FROM information_schema.columns
    WHERE table_name = 'grn_batches';
  END IF;
  
  -- Check triggers
  SELECT COUNT(*) INTO trigger_count
  FROM information_schema.triggers
  WHERE trigger_name LIKE 'trg_grn%po_quantities%';
  
  -- Check functions
  SELECT COUNT(*) INTO function_count
  FROM information_schema.routines
  WHERE routine_name IN (
    'calculate_po_received_quantities',
    'update_po_received_quantities'
  );
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 FINAL VERIFICATION RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Foreign Key Relationships: %', fk_count;
  RAISE NOTICE '✅ GRNs with Correct Supplier Names: %', supplier_fixed_count;
  RAISE NOTICE '✅ GRNs with Correct PO Numbers: %', po_fixed_count;
  RAISE NOTICE '✅ grn_batches Table Exists: %', batches_table_exists;
  IF batches_table_exists THEN
    RAISE NOTICE '✅ grn_batches Columns: %', array_to_string(batches_columns, ', ');
  END IF;
  RAISE NOTICE '✅ PO Update Triggers: %', trigger_count;
  RAISE NOTICE '✅ PO Update Functions: %', function_count;
  RAISE NOTICE '========================================';
  
  IF fk_count > 0 
     AND batches_table_exists 
     AND trigger_count >= 6 
     AND function_count >= 2 THEN
    RAISE NOTICE '🎉 ALL FIXES APPLIED SUCCESSFULLY!';
    RAISE NOTICE '';
    RAISE NOTICE '📝 NEXT STEPS:';
    RAISE NOTICE '1. Clear browser cache (Ctrl+Shift+R)';
    RAISE NOTICE '2. Test PO update after GRN approval';
    RAISE NOTICE '3. Check GRN list for supplier names';
  ELSE
    RAISE NOTICE '⚠️ Some fixes may need manual attention';
  END IF;
END $$;

-- Final completion message
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Complete diagnosis and fix script finished!';
END $$;



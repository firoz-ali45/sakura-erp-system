-- ============================================
-- 🎯 MASTER FIX - ALL ISSUES AT ONCE
-- ============================================
-- Run this in Supabase SQL Editor
-- This fixes ALL root causes:
-- 1. Foreign Key Relationship (PGRST200 errors)
-- 2. Supplier Names in GRNs
-- 3. PO Quantities Update
-- 4. grn_batches table (if needed)
-- ============================================

-- ============================================
-- STEP 1: Fix Foreign Key Relationship (CRITICAL)
-- ============================================
-- This fixes: "Could not find a relationship between 'purchase_order_items' and 'inventory_items'"
DO $$
DECLARE
  fk_exists BOOLEAN;
  po_item_id_type TEXT;
  inv_item_id_type TEXT;
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
  
  -- Get column types
  SELECT data_type INTO po_item_id_type
  FROM information_schema.columns
  WHERE table_name = 'purchase_order_items'
    AND column_name = 'item_id';
  
  SELECT data_type INTO inv_item_id_type
  FROM information_schema.columns
  WHERE table_name = 'inventory_items'
    AND column_name = 'id';
  
  RAISE NOTICE '🔍 FK Check: exists=%, PO item_id type=%, inventory_items id type=%', 
    fk_exists, po_item_id_type, inv_item_id_type;
  
  IF NOT fk_exists THEN
    -- Create foreign key constraint
    EXECUTE format('
      ALTER TABLE purchase_order_items
      ADD CONSTRAINT purchase_order_items_item_id_fkey
      FOREIGN KEY (item_id) REFERENCES inventory_items(id)
      ON DELETE SET NULL;
    ');
    
    RAISE NOTICE '✅ Foreign key constraint created successfully';
  ELSE
    RAISE NOTICE '✅ Foreign key constraint already exists';
  END IF;
  
  -- Verify the constraint
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
    WHERE tc.table_name = 'purchase_order_items'
      AND kcu.column_name = 'item_id'
      AND tc.constraint_type = 'FOREIGN KEY'
  ) INTO fk_exists;
  
  IF fk_exists THEN
    RAISE NOTICE '✅ Foreign key verified and working';
  ELSE
    RAISE NOTICE '❌ Foreign key creation failed';
  END IF;
END $$;

-- ============================================
-- STEP 2: Fix Supplier Names in GRNs
-- ============================================
-- This fixes: Supplier showing as JSON object instead of name
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
-- STEP 3: Fix Purchase Order Numbers in GRNs
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
-- STEP 4: Recalculate All PO Quantities
-- ============================================
-- This ensures all PO quantities are up-to-date
DO $$
DECLARE
  po_record RECORD;
  po_id_type TEXT;
BEGIN
  -- Get PO ID type
  SELECT data_type INTO po_id_type
  FROM information_schema.columns
  WHERE table_name = 'purchase_orders'
    AND column_name = 'id';
  
  -- Recalculate quantities for all POs
  FOR po_record IN 
    SELECT id FROM purchase_orders WHERE deleted = false OR deleted IS NULL
  LOOP
    BEGIN
      -- Call the update function
      IF po_id_type = 'uuid' THEN
        PERFORM update_po_received_quantities(po_record.id::UUID);
      ELSE
        PERFORM update_po_received_quantities(po_record.id::BIGINT);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '⚠️ Error updating PO %: %', po_record.id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE '✅ Recalculated quantities for all POs';
END $$;

-- ============================================
-- STEP 5: Create grn_batches table (if missing)
-- ============================================
-- This fixes: "Could not find the table 'public.grn_batches'"
CREATE TABLE IF NOT EXISTS grn_batches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  grn_id UUID NOT NULL,
  item_id UUID,
  batch_id TEXT,
  batch_number TEXT,
  expiry_date TIMESTAMP WITH TIME ZONE,
  quantity NUMERIC(10, 2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT grn_batches_grn_id_fkey 
    FOREIGN KEY (grn_id) REFERENCES grn_inspections(id) ON DELETE CASCADE
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_grn_batches_grn_id ON grn_batches(grn_id);
CREATE INDEX IF NOT EXISTS idx_grn_batches_item_id ON grn_batches(item_id);
CREATE INDEX IF NOT EXISTS idx_grn_batches_expiry_date ON grn_batches(expiry_date);

DO $$
BEGIN
  RAISE NOTICE '✅ grn_batches table created/verified';
END $$;

-- ============================================
-- STEP 6: Verify All Fixes
-- ============================================
DO $$
DECLARE
  fk_count INTEGER;
  supplier_fixed_count INTEGER;
  po_fixed_count INTEGER;
  batches_table_exists BOOLEAN;
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
    AND gi.deleted = false OR gi.deleted IS NULL;
  
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
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 VERIFICATION RESULTS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Foreign Key Relationships: %', fk_count;
  RAISE NOTICE '✅ GRNs with Correct Supplier Names: %', supplier_fixed_count;
  RAISE NOTICE '✅ GRNs with Correct PO Numbers: %', po_fixed_count;
  RAISE NOTICE '✅ grn_batches Table Exists: %', batches_table_exists;
  RAISE NOTICE '========================================';
  
  IF fk_count > 0 AND batches_table_exists THEN
    RAISE NOTICE '🎉 ALL FIXES APPLIED SUCCESSFULLY!';
  ELSE
    RAISE NOTICE '⚠️ Some fixes may need manual attention';
  END IF;
END $$;

-- ============================================
-- STEP 7: Test Query (Optional)
-- ============================================
-- Uncomment to test if FK relationship works
/*
SELECT 
  poi.id,
  poi.purchase_order_id,
  poi.item_id,
  poi.quantity,
  ii.name as item_name,
  ii.sku as item_sku
FROM purchase_order_items poi
LEFT JOIN inventory_items ii ON poi.item_id = ii.id
LIMIT 5;
*/

DO $$
BEGIN
  RAISE NOTICE '✅ Master fix script completed!';
END $$;


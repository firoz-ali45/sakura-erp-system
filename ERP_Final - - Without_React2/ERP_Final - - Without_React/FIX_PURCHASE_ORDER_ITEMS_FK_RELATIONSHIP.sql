-- Fix Purchase Order Items Foreign Key Relationship
-- This creates the missing foreign key relationship between purchase_order_items and inventory_items
-- Run this in Supabase SQL Editor

-- Step 1: Check if foreign key exists
SELECT 
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'purchase_order_items'
  AND kcu.column_name = 'item_id';

-- Step 2: Check if item_id column exists and its type
SELECT 
  column_name,
  data_type,
  udt_name,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'purchase_order_items'
  AND column_name = 'item_id';

-- Step 3: Check inventory_items.id type
SELECT 
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'inventory_items'
  AND column_name = 'id';

-- Step 4: Add foreign key if it doesn't exist
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
  
  RAISE NOTICE 'FK exists: %, PO item_id type: %, inventory_items id type: %', 
    fk_exists, po_item_id_type, inv_item_id_type;
  
  IF NOT fk_exists THEN
    -- Create foreign key constraint
    ALTER TABLE purchase_order_items
    ADD CONSTRAINT purchase_order_items_item_id_fkey
    FOREIGN KEY (item_id) REFERENCES inventory_items(id);
    
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

-- Step 5: Verify the relationship works
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


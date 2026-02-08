-- Create GRN (Goods Receipt Note) Tables in Supabase
-- Run this SQL in Supabase SQL Editor
-- This creates grn_inspections and grn_inspection_items tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 1: Create grn_inspections table with dynamic type checking
DO $$ 
DECLARE
    supplier_id_type TEXT;
    po_id_type TEXT;
BEGIN
    -- Get the actual data type of suppliers.id
    SELECT data_type INTO supplier_id_type
    FROM information_schema.columns
    WHERE table_name='suppliers' 
    AND column_name='id' 
    AND table_schema='public';
    
    -- Get the actual data type of purchase_orders.id (if table exists)
    SELECT data_type INTO po_id_type
    FROM information_schema.columns
    WHERE table_name='purchase_orders' 
    AND column_name='id' 
    AND table_schema='public';
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='grn_inspections' AND table_schema='public') THEN
        -- Create table with dynamic types based on suppliers.id and purchase_orders.id
        EXECUTE FORMAT('
            CREATE TABLE grn_inspections (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                grn_number TEXT UNIQUE NOT NULL,
                purchase_order_id %s, -- Dynamically set type
                purchase_order_number TEXT,
                supplier_id %s, -- Dynamically set type
                supplier_name TEXT,
                supplier_code TEXT,
                vendor_batch_number TEXT,
                receiving_location TEXT,
                invoice_number TEXT,
                external_reference_id TEXT,
                grn_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
                inspection_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                status TEXT DEFAULT ''pending'' CHECK (status IN (''draft'', ''pending'', ''passed'', ''hold'', ''rejected'', ''conditional'')),
                qc_status TEXT CHECK (qc_status IN (''PASS'', ''HOLD'', ''REJECT'')),
                disposition TEXT,
                qa_remarks TEXT,
                corrective_action_required BOOLEAN DEFAULT FALSE,
                received_by UUID,
                received_by_name TEXT,
                quality_checked_by UUID,
                quality_checked_by_name TEXT,
                approved_by UUID,
                approved_by_name TEXT,
                approval_date TIMESTAMP WITH TIME ZONE,
                notes TEXT,
                created_by UUID,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                deleted BOOLEAN DEFAULT FALSE,
                deleted_at TIMESTAMP WITH TIME ZONE
            );
        ', 
        COALESCE(po_id_type, 'UUID'),
        COALESCE(supplier_id_type, 'UUID')
        );
        
        RAISE NOTICE 'Table grn_inspections created successfully with supplier_id type: %, purchase_order_id type: %', 
            COALESCE(supplier_id_type, 'UUID (default)'), 
            COALESCE(po_id_type, 'UUID (default)');
    ELSE
        RAISE NOTICE 'Table grn_inspections already exists, adding missing columns...';
    END IF;
END $$;

-- Create grn_inspection_items table
CREATE TABLE IF NOT EXISTS grn_inspection_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grn_inspection_id UUID NOT NULL REFERENCES grn_inspections(id) ON DELETE CASCADE,
    purchase_order_id UUID, -- Link to purchase order
    item_id UUID, -- Foreign key to inventory_items
    item_code TEXT,
    item_name TEXT,
    item_description TEXT,
    unit_of_measure TEXT,
    ordered_quantity NUMERIC(10, 2) DEFAULT 0, -- CRITICAL: Ordered quantity from PO
    received_quantity NUMERIC(10, 2) NOT NULL DEFAULT 0,
    expiry_date TIMESTAMP WITH TIME ZONE,
    packaging_condition TEXT CHECK (packaging_condition IN ('Good', 'Damaged')),
    visual_inspection TEXT CHECK (visual_inspection IN ('Pass', 'Fail')),
    temperature_check TEXT,
    non_conformance_reason TEXT,
    non_conformance_severity TEXT CHECK (non_conformance_severity IN ('Critical', 'Major', 'Minor')),
    quality_status TEXT CHECK (quality_status IN ('passed', 'failed', 'conditional')),
    batch_number TEXT,
    test_results JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Add missing columns to grn_inspections (if table exists)
DO $$ 
DECLARE
    supplier_id_type TEXT;
    po_id_type TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='grn_inspections' AND table_schema='public') THEN
        -- Get the actual data type of suppliers.id
        SELECT data_type INTO supplier_id_type
        FROM information_schema.columns
        WHERE table_name='suppliers' 
        AND column_name='id' 
        AND table_schema='public';
        
        -- Get the actual data type of purchase_orders.id
        SELECT data_type INTO po_id_type
        FROM information_schema.columns
        WHERE table_name='purchase_orders' 
        AND column_name='id' 
        AND table_schema='public';
        
        -- Add supplier_id column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='supplier_id' AND table_schema='public') THEN
            EXECUTE FORMAT('ALTER TABLE grn_inspections ADD COLUMN supplier_id %s;', COALESCE(supplier_id_type, 'UUID'));
        END IF;
        
        -- Add purchase_order_id column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='purchase_order_id' AND table_schema='public') THEN
            EXECUTE FORMAT('ALTER TABLE grn_inspections ADD COLUMN purchase_order_id %s;', COALESCE(po_id_type, 'UUID'));
        END IF;
        
        -- Add other missing columns
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS purchase_order_number TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS supplier_name TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS supplier_code TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS vendor_batch_number TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS receiving_location TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS invoice_number TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS external_reference_id TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS grn_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS inspection_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS qc_status TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS disposition TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS qa_remarks TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS corrective_action_required BOOLEAN DEFAULT FALSE;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS received_by UUID;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS received_by_name TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS quality_checked_by UUID;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS quality_checked_by_name TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS approved_by UUID;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS approved_by_name TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS approval_date TIMESTAMP WITH TIME ZONE;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS notes TEXT;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS created_by UUID;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT FALSE;
        ALTER TABLE grn_inspections ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
        
        -- Add grn_number constraint if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='grn_inspections_grn_number_key' AND table_name='grn_inspections') THEN
            ALTER TABLE grn_inspections ADD CONSTRAINT grn_inspections_grn_number_key UNIQUE (grn_number);
        END IF;
        
        -- Add NOT NULL constraint to grn_number if column exists
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='grn_number' AND table_schema='public') THEN
            ALTER TABLE grn_inspections ALTER COLUMN grn_number SET NOT NULL;
        END IF;
    END IF;
END $$;

-- Step 3: Fix existing table if supplier_id type is wrong
DO $$ 
DECLARE
    supplier_id_type TEXT;
    po_id_type TEXT;
    existing_supplier_id_type TEXT;
    existing_po_id_type TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='grn_inspections' AND table_schema='public') THEN
        -- Get the actual data type of suppliers.id
        SELECT data_type INTO supplier_id_type
        FROM information_schema.columns
        WHERE table_name='suppliers' 
        AND column_name='id' 
        AND table_schema='public';
        
        -- Get the actual data type of purchase_orders.id
        SELECT data_type INTO po_id_type
        FROM information_schema.columns
        WHERE table_name='purchase_orders' 
        AND column_name='id' 
        AND table_schema='public';
        
        -- Get existing supplier_id type in grn_inspections
        SELECT data_type INTO existing_supplier_id_type
        FROM information_schema.columns
        WHERE table_name='grn_inspections' 
        AND column_name='supplier_id' 
        AND table_schema='public';
        
        -- Get existing purchase_order_id type in grn_inspections
        SELECT data_type INTO existing_po_id_type
        FROM information_schema.columns
        WHERE table_name='grn_inspections' 
        AND column_name='purchase_order_id' 
        AND table_schema='public';
        
        -- Fix supplier_id type if it doesn't match
        IF existing_supplier_id_type IS NOT NULL 
           AND supplier_id_type IS NOT NULL 
           AND existing_supplier_id_type != supplier_id_type THEN
            -- Drop existing constraint if it exists
            IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
                      WHERE constraint_name='grn_inspections_supplier_id_fkey' 
                      AND table_name='grn_inspections') THEN
                ALTER TABLE grn_inspections DROP CONSTRAINT grn_inspections_supplier_id_fkey;
            END IF;
            -- Alter column type
            EXECUTE FORMAT('ALTER TABLE grn_inspections ALTER COLUMN supplier_id TYPE %s USING supplier_id::%s;', 
                          supplier_id_type, supplier_id_type);
            RAISE NOTICE 'Fixed supplier_id type from % to %', existing_supplier_id_type, supplier_id_type;
        END IF;
        
        -- Fix purchase_order_id type if it doesn't match
        IF existing_po_id_type IS NOT NULL 
           AND po_id_type IS NOT NULL 
           AND existing_po_id_type != po_id_type THEN
            -- Drop existing constraint if it exists
            IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
                      WHERE constraint_name='grn_inspections_purchase_order_id_fkey' 
                      AND table_name='grn_inspections') THEN
                ALTER TABLE grn_inspections DROP CONSTRAINT grn_inspections_purchase_order_id_fkey;
            END IF;
            -- Alter column type
            EXECUTE FORMAT('ALTER TABLE grn_inspections ALTER COLUMN purchase_order_id TYPE %s USING purchase_order_id::%s;', 
                          po_id_type, po_id_type);
            RAISE NOTICE 'Fixed purchase_order_id type from % to %', existing_po_id_type, po_id_type;
        END IF;
    END IF;
END $$;

-- Step 3.5: Add missing columns to grn_inspection_items (if table exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='grn_inspection_items' AND table_schema='public') THEN
        -- Add ordered_quantity column if it doesn't exist (CRITICAL for PO items)
        ALTER TABLE grn_inspection_items ADD COLUMN IF NOT EXISTS ordered_quantity NUMERIC(10, 2) DEFAULT 0;
        
        -- Add purchase_order_id column if it doesn't exist (for linking to PO)
        ALTER TABLE grn_inspection_items ADD COLUMN IF NOT EXISTS purchase_order_id UUID;
        
        RAISE NOTICE 'Added missing columns to grn_inspection_items table';
    END IF;
END $$;

-- Step 4: Add foreign key constraints conditionally
DO $$ 
BEGIN
    -- Add foreign key constraint for supplier_id
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='suppliers' AND table_schema='public')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='supplier_id' AND table_schema='public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='grn_inspections_supplier_id_fkey' AND table_name='grn_inspections') THEN
        ALTER TABLE grn_inspections 
        ADD CONSTRAINT grn_inspections_supplier_id_fkey 
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
        RAISE NOTICE 'Foreign key constraint grn_inspections_supplier_id_fkey added';
    END IF;
    
    -- Add foreign key constraint for purchase_order_id
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_orders' AND table_schema='public')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='purchase_order_id' AND table_schema='public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='grn_inspections_purchase_order_id_fkey' AND table_name='grn_inspections') THEN
        ALTER TABLE grn_inspections 
        ADD CONSTRAINT grn_inspections_purchase_order_id_fkey 
        FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id);
        RAISE NOTICE 'Foreign key constraint grn_inspections_purchase_order_id_fkey added';
    END IF;
    
    -- Add foreign key constraint for grn_inspection_items.item_id to inventory_items.id (CRITICAL for item relationship)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='inventory_items' AND table_schema='public')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspection_items' AND column_name='item_id' AND table_schema='public')
       AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='grn_inspection_items_item_id_fkey' AND table_name='grn_inspection_items') THEN
        ALTER TABLE grn_inspection_items 
        ADD CONSTRAINT grn_inspection_items_item_id_fkey 
        FOREIGN KEY (item_id) REFERENCES inventory_items(id);
        RAISE NOTICE 'Foreign key constraint grn_inspection_items_item_id_fkey added';
    END IF;
END $$;

-- Create indexes for better performance (only if columns exist)
DO $$ 
BEGIN
    -- Indexes for grn_inspections
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='grn_number') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspections_grn_number ON grn_inspections(grn_number);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='purchase_order_id') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspections_po_id ON grn_inspections(purchase_order_id);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='supplier_id') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspections_supplier_id ON grn_inspections(supplier_id);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='status') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspections_status ON grn_inspections(status);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='qc_status') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspections_qc_status ON grn_inspections(qc_status);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='grn_date') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspections_grn_date ON grn_inspections(grn_date);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspections' AND column_name='deleted') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspections_deleted ON grn_inspections(deleted);
    END IF;
    
    -- Indexes for grn_inspection_items
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspection_items' AND column_name='grn_inspection_id') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_grn_id ON grn_inspection_items(grn_inspection_id);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='grn_inspection_items' AND column_name='item_id') THEN
        CREATE INDEX IF NOT EXISTS idx_grn_inspection_items_item_id ON grn_inspection_items(item_id);
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE grn_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE grn_inspection_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for grn_inspections
DROP POLICY IF EXISTS "Enable read access for all users" ON grn_inspections;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON grn_inspections;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON grn_inspections;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON grn_inspections;

CREATE POLICY "Enable read access for all users"
  ON grn_inspections FOR SELECT
  USING (true);

CREATE POLICY "Enable insert for authenticated users"
  ON grn_inspections FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users"
  ON grn_inspections FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users"
  ON grn_inspections FOR DELETE
  USING (true);

-- RLS Policies for grn_inspection_items
DROP POLICY IF EXISTS "Enable read access for all users" ON grn_inspection_items;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON grn_inspection_items;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON grn_inspection_items;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON grn_inspection_items;

CREATE POLICY "Enable read access for all users"
  ON grn_inspection_items FOR SELECT
  USING (true);

CREATE POLICY "Enable insert for authenticated users"
  ON grn_inspection_items FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users"
  ON grn_inspection_items FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users"
  ON grn_inspection_items FOR DELETE
  USING (true);

-- Verify tables are created
SELECT 
  schemaname,
  tablename
FROM pg_tables
WHERE tablename IN ('grn_inspections', 'grn_inspection_items');


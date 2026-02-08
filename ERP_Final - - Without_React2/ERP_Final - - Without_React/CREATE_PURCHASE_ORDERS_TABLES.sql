-- Create Purchase Orders Tables in Supabase (Foodics Format Compatible)
-- Run this SQL in Supabase SQL Editor
-- This creates purchase_orders and purchase_order_items tables matching Foodics export format

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 1: Create purchase_orders table if it doesn't exist
DO $$ 
DECLARE
    supplier_id_type TEXT;
    existing_po_id_type TEXT;
BEGIN
    -- Get the actual data type of suppliers.id
    SELECT data_type INTO supplier_id_type
    FROM information_schema.columns
    WHERE table_name='suppliers' 
    AND column_name='id' 
    AND table_schema='public';
    
    -- Check if purchase_orders table already exists and get its id type
    SELECT data_type INTO existing_po_id_type
    FROM information_schema.columns
    WHERE table_name='purchase_orders' 
    AND column_name='id' 
    AND table_schema='public';
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_orders' AND table_schema='public') THEN
        -- Create table based on suppliers.id type
        IF supplier_id_type = 'bigint' THEN
            CREATE TABLE purchase_orders (
                id BIGSERIAL PRIMARY KEY,
                po_number TEXT UNIQUE NOT NULL,
                supplier_id BIGINT,
                supplier_name TEXT,
                destination TEXT,
                status TEXT DEFAULT 'pending',
                business_date DATE,
                order_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                expected_date TIMESTAMP WITH TIME ZONE,
                total_amount NUMERIC(10, 2) DEFAULT 0,
                vat_amount NUMERIC(10, 2) DEFAULT 0,
                notes TEXT,
                created_by BIGINT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                deleted BOOLEAN DEFAULT FALSE,
                deleted_at TIMESTAMP WITH TIME ZONE
            );
            -- Add foreign key constraint separately
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='suppliers' AND table_schema='public') THEN
                ALTER TABLE purchase_orders 
                ADD CONSTRAINT purchase_orders_supplier_id_fkey 
                FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
            END IF;
        ELSE
            -- Default to UUID
            CREATE TABLE purchase_orders (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                po_number TEXT UNIQUE NOT NULL,
                supplier_id UUID,
                supplier_name TEXT,
                destination TEXT,
                status TEXT DEFAULT 'pending',
                business_date DATE,
                order_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                expected_date TIMESTAMP WITH TIME ZONE,
                total_amount NUMERIC(10, 2) DEFAULT 0,
                vat_amount NUMERIC(10, 2) DEFAULT 0,
                notes TEXT,
                created_by UUID,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                deleted BOOLEAN DEFAULT FALSE,
                deleted_at TIMESTAMP WITH TIME ZONE
            );
            -- Add foreign key constraint separately
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='suppliers' AND table_schema='public') THEN
                ALTER TABLE purchase_orders 
                ADD CONSTRAINT purchase_orders_supplier_id_fkey 
                FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
            END IF;
        END IF;
        RAISE NOTICE 'Table purchase_orders created successfully with supplier_id type: %', COALESCE(supplier_id_type, 'UUID (default)');
    ELSE
        RAISE NOTICE 'Table purchase_orders already exists (id type: %), adding missing columns...', COALESCE(existing_po_id_type, 'unknown');
    END IF;
END $$;

-- Step 2: Add missing columns to purchase_orders (if table exists)
DO $$ 
DECLARE
    supplier_id_type TEXT;
BEGIN
    -- Get the actual data type of suppliers.id
    SELECT data_type INTO supplier_id_type
    FROM information_schema.columns
    WHERE table_name='suppliers' 
    AND column_name='id' 
    AND table_schema='public';
    
    -- Check if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_orders' AND table_schema='public') THEN
        -- Add po_number if not exists (Foodics: reference)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='po_number' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN po_number TEXT;
            RAISE NOTICE 'Column po_number added';
        END IF;
        
        -- Add supplier_name if not exists (Foodics: supplier with Arabic)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='supplier_name' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN supplier_name TEXT;
            RAISE NOTICE 'Column supplier_name added';
        END IF;
        
        -- Add supplier_id if not exists (match the type of suppliers.id)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='supplier_id' AND table_schema='public') THEN
            -- Add column with matching type
            IF supplier_id_type = 'bigint' THEN
                ALTER TABLE purchase_orders ADD COLUMN supplier_id BIGINT;
                RAISE NOTICE 'Column supplier_id added with type: BIGINT';
            ELSIF supplier_id_type = 'uuid' THEN
                ALTER TABLE purchase_orders ADD COLUMN supplier_id UUID;
                RAISE NOTICE 'Column supplier_id added with type: UUID';
            ELSE
                -- Default to UUID if type unknown
                ALTER TABLE purchase_orders ADD COLUMN supplier_id UUID;
                RAISE NOTICE 'Column supplier_id added with type: UUID (default, suppliers.id type: %)', COALESCE(supplier_id_type, 'unknown');
            END IF;
        END IF;
        
        -- Add destination if not exists (Foodics: destination)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='destination' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN destination TEXT;
            RAISE NOTICE 'Column destination added';
        END IF;
        
        -- Add status if not exists (Foodics: status)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='status' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN status TEXT DEFAULT 'pending';
            RAISE NOTICE 'Column status added';
        END IF;
        
        -- Add business_date if not exists (Foodics: business_date)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='business_date' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN business_date DATE;
            RAISE NOTICE 'Column business_date added';
        END IF;
        
        -- Add order_date if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='order_date' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN order_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            RAISE NOTICE 'Column order_date added';
        END IF;
        
        -- Add expected_date if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='expected_date' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN expected_date TIMESTAMP WITH TIME ZONE;
            RAISE NOTICE 'Column expected_date added';
        END IF;
        
        -- Add total_amount if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='total_amount' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN total_amount NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column total_amount added';
        END IF;
        
        -- Add vat_amount if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='vat_amount' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN vat_amount NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column vat_amount added';
        END IF;
        
        -- Add notes if not exists (Foodics: notes)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='notes' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN notes TEXT;
            RAISE NOTICE 'Column notes added';
        END IF;
        
        -- Add created_by if not exists (match the type of purchase_orders.id)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='created_by' AND table_schema='public') THEN
            DECLARE
                po_id_type TEXT;
            BEGIN
                SELECT data_type INTO po_id_type
                FROM information_schema.columns
                WHERE table_name='purchase_orders' 
                AND column_name='id' 
                AND table_schema='public';
                
                IF po_id_type = 'bigint' THEN
                    ALTER TABLE purchase_orders ADD COLUMN created_by BIGINT;
                ELSIF po_id_type = 'uuid' THEN
                    ALTER TABLE purchase_orders ADD COLUMN created_by UUID;
                ELSE
                    ALTER TABLE purchase_orders ADD COLUMN created_by UUID;
                END IF;
                RAISE NOTICE 'Column created_by added';
            END;
        END IF;
        
        -- Add updated_at if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='updated_at' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            RAISE NOTICE 'Column updated_at added';
        END IF;
        
        -- Add deleted if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='deleted' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN deleted BOOLEAN DEFAULT FALSE;
            RAISE NOTICE 'Column deleted added';
        END IF;
        
        -- Add deleted_at if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='deleted_at' AND table_schema='public') THEN
            ALTER TABLE purchase_orders ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
            RAISE NOTICE 'Column deleted_at added';
        END IF;
    END IF;
END $$;

-- Step 3: Add unique constraint for po_number (after column exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='po_number' AND table_schema='public') THEN
        -- Drop existing unique constraint if exists
        ALTER TABLE purchase_orders DROP CONSTRAINT IF EXISTS purchase_orders_po_number_key;
        -- Add unique constraint
        CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_orders_po_number_unique 
        ON purchase_orders(po_number) 
        WHERE po_number IS NOT NULL;
        RAISE NOTICE 'Unique constraint on po_number created';
    END IF;
END $$;

-- Step 4: Create purchase_order_items table if it doesn't exist
-- First check what type purchase_orders.id is
DO $$ 
DECLARE
    po_id_type TEXT;
BEGIN
    -- Get the actual data type of purchase_orders.id
    SELECT data_type INTO po_id_type
    FROM information_schema.columns
    WHERE table_name='purchase_orders' 
    AND column_name='id' 
    AND table_schema='public';
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_order_items' AND table_schema='public') THEN
        -- Create table based on purchase_orders.id type
        IF po_id_type = 'uuid' THEN
            CREATE TABLE purchase_order_items (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                purchase_order_id UUID NOT NULL,
                po_number TEXT,
                supplier_name TEXT,
                item_id UUID,
                item_name TEXT,
                name_localized TEXT,
                item_sku TEXT,
                quantity NUMERIC(10, 2) NOT NULL DEFAULT 0,
                unit TEXT,
                unit_price NUMERIC(10, 2) DEFAULT 0,
                total_amount NUMERIC(10, 2) DEFAULT 0,
                quantity_received NUMERIC(10, 2) DEFAULT 0,
                vat_rate NUMERIC(5, 2) DEFAULT 0,
                vat_amount NUMERIC(10, 2) DEFAULT 0,
                batch_number TEXT,
                expiry_date TIMESTAMP WITH TIME ZONE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            -- Add foreign key constraint separately
            ALTER TABLE purchase_order_items 
            ADD CONSTRAINT purchase_order_items_purchase_order_id_fkey 
            FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE;
        ELSIF po_id_type = 'bigint' THEN
            CREATE TABLE purchase_order_items (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                purchase_order_id BIGINT NOT NULL,
                po_number TEXT,
                supplier_name TEXT,
                item_id UUID,
                item_name TEXT,
                name_localized TEXT,
                item_sku TEXT,
                quantity NUMERIC(10, 2) NOT NULL DEFAULT 0,
                unit TEXT,
                unit_price NUMERIC(10, 2) DEFAULT 0,
                total_amount NUMERIC(10, 2) DEFAULT 0,
                quantity_received NUMERIC(10, 2) DEFAULT 0,
                vat_rate NUMERIC(5, 2) DEFAULT 0,
                vat_amount NUMERIC(10, 2) DEFAULT 0,
                batch_number TEXT,
                expiry_date TIMESTAMP WITH TIME ZONE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            -- Add foreign key constraint separately
            ALTER TABLE purchase_order_items 
            ADD CONSTRAINT purchase_order_items_purchase_order_id_fkey 
            FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE;
        ELSE
            -- Default to UUID if type unknown
            CREATE TABLE purchase_order_items (
                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                purchase_order_id UUID NOT NULL,
                po_number TEXT,
                supplier_name TEXT,
                item_id UUID,
                item_name TEXT,
                name_localized TEXT,
                item_sku TEXT,
                quantity NUMERIC(10, 2) NOT NULL DEFAULT 0,
                unit TEXT,
                unit_price NUMERIC(10, 2) DEFAULT 0,
                total_amount NUMERIC(10, 2) DEFAULT 0,
                quantity_received NUMERIC(10, 2) DEFAULT 0,
                vat_rate NUMERIC(5, 2) DEFAULT 0,
                vat_amount NUMERIC(10, 2) DEFAULT 0,
                batch_number TEXT,
                expiry_date TIMESTAMP WITH TIME ZONE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
        END IF;
        RAISE NOTICE 'Table purchase_order_items created successfully with purchase_order_id type: %', COALESCE(po_id_type, 'UUID (default)');
    ELSE
        RAISE NOTICE 'Table purchase_order_items already exists, adding missing columns...';
    END IF;
END $$;

-- Step 5: Add missing columns to purchase_order_items (if table exists)
DO $$ 
DECLARE
    po_id_type TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_order_items' AND table_schema='public') THEN
        -- Get the actual data type of purchase_orders.id first
        SELECT data_type INTO po_id_type
        FROM information_schema.columns
        WHERE table_name='purchase_orders' 
        AND column_name='id' 
        AND table_schema='public';
        
        -- Add po_number if not exists (Foodics: reference)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='po_number' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN po_number TEXT;
            RAISE NOTICE 'Column po_number added to purchase_order_items';
        END IF;
        
        -- Add supplier_name if not exists (Foodics: supplier)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='supplier_name' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN supplier_name TEXT;
            RAISE NOTICE 'Column supplier_name added to purchase_order_items';
        END IF;
        
        -- Add purchase_order_id if not exists (match the type of purchase_orders.id)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='purchase_order_id' AND table_schema='public') THEN
            -- Add column with matching type
            IF po_id_type = 'bigint' THEN
                ALTER TABLE purchase_order_items ADD COLUMN purchase_order_id BIGINT;
                RAISE NOTICE 'Column purchase_order_id added to purchase_order_items with type: BIGINT';
            ELSIF po_id_type = 'uuid' THEN
                ALTER TABLE purchase_order_items ADD COLUMN purchase_order_id UUID;
                RAISE NOTICE 'Column purchase_order_id added to purchase_order_items with type: UUID';
            ELSE
                -- Default to UUID if type unknown
                ALTER TABLE purchase_order_items ADD COLUMN purchase_order_id UUID;
                RAISE NOTICE 'Column purchase_order_id added to purchase_order_items with type: UUID (default, purchase_orders.id type: %)', COALESCE(po_id_type, 'unknown');
            END IF;
        END IF;
        
        -- Add foreign key constraint separately (after column exists)
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='purchase_order_id' AND table_schema='public') THEN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints 
                WHERE constraint_name='purchase_order_items_purchase_order_id_fkey'
                AND table_schema='public'
            ) THEN
                BEGIN
                    ALTER TABLE purchase_order_items 
                    ADD CONSTRAINT purchase_order_items_purchase_order_id_fkey 
                    FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE;
                    RAISE NOTICE 'Foreign key constraint added for purchase_order_id';
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE 'Could not add foreign key constraint: %', SQLERRM;
                END;
            END IF;
        END IF;
        
        -- Add item_id if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='item_id' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN item_id UUID;
            RAISE NOTICE 'Column item_id added to purchase_order_items';
        END IF;
        
        -- Add item_name if not exists (Foodics: name)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='item_name' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN item_name TEXT;
            RAISE NOTICE 'Column item_name added to purchase_order_items';
        END IF;
        
        -- Add name_localized if not exists (Foodics: name_localized)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='name_localized' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN name_localized TEXT;
            RAISE NOTICE 'Column name_localized added to purchase_order_items';
        END IF;
        
        -- Add item_sku if not exists (Foodics: sku)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='item_sku' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN item_sku TEXT;
            RAISE NOTICE 'Column item_sku added to purchase_order_items';
        END IF;
        
        -- Add quantity if not exists (Foodics: quantity)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='quantity' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN quantity NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column quantity added to purchase_order_items';
        END IF;
        
        -- Add unit if not exists (Foodics: unit)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='unit' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN unit TEXT;
            RAISE NOTICE 'Column unit added to purchase_order_items';
        END IF;
        
        -- Add unit_price if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='unit_price' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN unit_price NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column unit_price added to purchase_order_items';
        END IF;
        
        -- Add total_amount if not exists (Foodics: total_cost)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='total_amount' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN total_amount NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column total_amount added to purchase_order_items';
        END IF;
        
        -- Add quantity_received if not exists (Foodics: quantity_received)
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='quantity_received' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN quantity_received NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column quantity_received added to purchase_order_items';
        END IF;
        
        -- Add vat_rate if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='vat_rate' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN vat_rate NUMERIC(5, 2) DEFAULT 0;
            RAISE NOTICE 'Column vat_rate added to purchase_order_items';
        END IF;
        
        -- Add vat_amount if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='vat_amount' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN vat_amount NUMERIC(10, 2) DEFAULT 0;
            RAISE NOTICE 'Column vat_amount added to purchase_order_items';
        END IF;
        
        -- Add batch_number if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='batch_number' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN batch_number TEXT;
            RAISE NOTICE 'Column batch_number added to purchase_order_items';
        END IF;
        
        -- Add expiry_date if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='expiry_date' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN expiry_date TIMESTAMP WITH TIME ZONE;
            RAISE NOTICE 'Column expiry_date added to purchase_order_items';
        END IF;
        
        -- Add created_at if not exists
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='created_at' AND table_schema='public') THEN
            ALTER TABLE purchase_order_items ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            RAISE NOTICE 'Column created_at added to purchase_order_items';
        END IF;
    END IF;
END $$;

-- Step 6: Add foreign key constraint for supplier_id (after columns exist)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='supplier_id' AND table_schema='public') THEN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='suppliers' AND table_schema='public') THEN
            -- Check if constraint doesn't already exist
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints 
                WHERE constraint_name='purchase_orders_supplier_id_fkey'
                AND table_schema='public'
            ) THEN
                BEGIN
                    -- Drop constraint if exists (in case of name mismatch)
                    ALTER TABLE purchase_orders DROP CONSTRAINT IF EXISTS purchase_orders_supplier_id_fkey;
                    -- Add foreign key constraint
                    ALTER TABLE purchase_orders ADD CONSTRAINT purchase_orders_supplier_id_fkey 
                    FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
                    RAISE NOTICE 'Foreign key constraint for supplier_id added';
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE NOTICE 'Could not add foreign key constraint for supplier_id: %', SQLERRM;
                END;
            ELSE
                RAISE NOTICE 'Foreign key constraint for supplier_id already exists';
            END IF;
        END IF;
    END IF;
END $$;

-- Step 7: Create indexes (ONLY after columns are confirmed to exist)
DO $$ 
BEGIN
    -- Indexes for purchase_orders (only if columns exist)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='po_number' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_po_number ON purchase_orders(po_number);
        RAISE NOTICE 'Index idx_purchase_orders_po_number created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='supplier_id' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
        RAISE NOTICE 'Index idx_purchase_orders_supplier_id created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='status' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);
        RAISE NOTICE 'Index idx_purchase_orders_status created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='business_date' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_business_date ON purchase_orders(business_date);
        RAISE NOTICE 'Index idx_purchase_orders_business_date created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='order_date' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_order_date ON purchase_orders(order_date);
        RAISE NOTICE 'Index idx_purchase_orders_order_date created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_orders' AND column_name='deleted' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_orders_deleted ON purchase_orders(deleted);
        RAISE NOTICE 'Index idx_purchase_orders_deleted created';
    END IF;
    
    -- Indexes for purchase_order_items (only if columns exist)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='purchase_order_id' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id ON purchase_order_items(purchase_order_id);
        RAISE NOTICE 'Index idx_purchase_order_items_po_id created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='po_number' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_number ON purchase_order_items(po_number);
        RAISE NOTICE 'Index idx_purchase_order_items_po_number created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='item_id' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_order_items_item_id ON purchase_order_items(item_id);
        RAISE NOTICE 'Index idx_purchase_order_items_item_id created';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='purchase_order_items' AND column_name='item_sku' AND table_schema='public') THEN
        CREATE INDEX IF NOT EXISTS idx_purchase_order_items_sku ON purchase_order_items(item_sku);
        RAISE NOTICE 'Index idx_purchase_order_items_sku created';
    END IF;
END $$;

-- Step 8: Enable Row Level Security
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_orders' AND table_schema='public') THEN
        ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'RLS enabled for purchase_orders';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_order_items' AND table_schema='public') THEN
        ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'RLS enabled for purchase_order_items';
    END IF;
END $$;

-- Step 9: Create RLS Policies for purchase_orders
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_orders' AND table_schema='public') THEN
        DROP POLICY IF EXISTS "Enable read access for all users" ON purchase_orders;
        DROP POLICY IF EXISTS "Enable insert for authenticated users" ON purchase_orders;
        DROP POLICY IF EXISTS "Enable update for authenticated users" ON purchase_orders;
        DROP POLICY IF EXISTS "Enable delete for authenticated users" ON purchase_orders;
        
        CREATE POLICY "Enable read access for all users"
          ON purchase_orders FOR SELECT
          USING (true);
        
        CREATE POLICY "Enable insert for authenticated users"
          ON purchase_orders FOR INSERT
          WITH CHECK (true);
        
        CREATE POLICY "Enable update for authenticated users"
          ON purchase_orders FOR UPDATE
          USING (true)
          WITH CHECK (true);
        
        CREATE POLICY "Enable delete for authenticated users"
          ON purchase_orders FOR DELETE
          USING (true);
        
        RAISE NOTICE 'RLS policies created for purchase_orders';
    END IF;
END $$;

-- Step 10: Create RLS Policies for purchase_order_items
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='purchase_order_items' AND table_schema='public') THEN
        DROP POLICY IF EXISTS "Enable read access for all users" ON purchase_order_items;
        DROP POLICY IF EXISTS "Enable insert for authenticated users" ON purchase_order_items;
        DROP POLICY IF EXISTS "Enable update for authenticated users" ON purchase_order_items;
        DROP POLICY IF EXISTS "Enable delete for authenticated users" ON purchase_order_items;
        
        CREATE POLICY "Enable read access for all users"
          ON purchase_order_items FOR SELECT
          USING (true);
        
        CREATE POLICY "Enable insert for authenticated users"
          ON purchase_order_items FOR INSERT
          WITH CHECK (true);
        
        CREATE POLICY "Enable update for authenticated users"
          ON purchase_order_items FOR UPDATE
          USING (true)
          WITH CHECK (true);
        
        CREATE POLICY "Enable delete for authenticated users"
          ON purchase_order_items FOR DELETE
          USING (true);
        
        RAISE NOTICE 'RLS policies created for purchase_order_items';
    END IF;
END $$;

-- Step 11: Verify tables and columns
SELECT 
    'purchase_orders' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name='purchase_orders' AND table_schema='public'
ORDER BY ordinal_position;

SELECT 
    'purchase_order_items' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name='purchase_order_items' AND table_schema='public'
ORDER BY ordinal_position;

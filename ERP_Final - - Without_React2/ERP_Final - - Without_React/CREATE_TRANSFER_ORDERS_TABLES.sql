-- Create Transfer Orders Tables in Supabase
-- Run this SQL in Supabase SQL Editor
-- This creates transfer_orders and transfer_order_items tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create transfer_orders table
CREATE TABLE IF NOT EXISTS transfer_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_number TEXT UNIQUE NOT NULL,
    from_location TEXT NOT NULL,
    to_location TEXT NOT NULL,
    transfer_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status TEXT DEFAULT 'pending' CHECK (status IN ('draft', 'pending', 'in_transit', 'completed', 'cancelled')),
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Create transfer_order_items table
CREATE TABLE IF NOT EXISTS transfer_order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_order_id UUID NOT NULL REFERENCES transfer_orders(id) ON DELETE CASCADE,
    item_id UUID,
    item_name TEXT,
    item_sku TEXT,
    quantity NUMERIC(10, 2) NOT NULL DEFAULT 0,
    transferred_quantity NUMERIC(10, 2) DEFAULT 0,
    batch_number TEXT,
    expiry_date TIMESTAMP WITH TIME ZONE,
    unit TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance (only if columns exist)
DO $$ 
BEGIN
    -- Indexes for transfer_orders
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='transfer_orders' AND column_name='transfer_number') THEN
        CREATE INDEX IF NOT EXISTS idx_transfer_orders_transfer_number ON transfer_orders(transfer_number);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='transfer_orders' AND column_name='status') THEN
        CREATE INDEX IF NOT EXISTS idx_transfer_orders_status ON transfer_orders(status);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='transfer_orders' AND column_name='transfer_date') THEN
        CREATE INDEX IF NOT EXISTS idx_transfer_orders_transfer_date ON transfer_orders(transfer_date);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='transfer_orders' AND column_name='deleted') THEN
        CREATE INDEX IF NOT EXISTS idx_transfer_orders_deleted ON transfer_orders(deleted);
    END IF;
    
    -- Indexes for transfer_order_items
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='transfer_order_items' AND column_name='transfer_order_id') THEN
        CREATE INDEX IF NOT EXISTS idx_transfer_order_items_transfer_id ON transfer_order_items(transfer_order_id);
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='transfer_order_items' AND column_name='item_id') THEN
        CREATE INDEX IF NOT EXISTS idx_transfer_order_items_item_id ON transfer_order_items(item_id);
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE transfer_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_order_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for transfer_orders
DROP POLICY IF EXISTS "Enable read access for all users" ON transfer_orders;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON transfer_orders;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON transfer_orders;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON transfer_orders;

CREATE POLICY "Enable read access for all users"
  ON transfer_orders FOR SELECT
  USING (true);

CREATE POLICY "Enable insert for authenticated users"
  ON transfer_orders FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users"
  ON transfer_orders FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users"
  ON transfer_orders FOR DELETE
  USING (true);

-- RLS Policies for transfer_order_items
DROP POLICY IF EXISTS "Enable read access for all users" ON transfer_order_items;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON transfer_order_items;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON transfer_order_items;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON transfer_order_items;

CREATE POLICY "Enable read access for all users"
  ON transfer_order_items FOR SELECT
  USING (true);

CREATE POLICY "Enable insert for authenticated users"
  ON transfer_order_items FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users"
  ON transfer_order_items FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users"
  ON transfer_order_items FOR DELETE
  USING (true);

-- Verify tables are created
SELECT 
  schemaname,
  tablename
FROM pg_tables
WHERE tablename IN ('transfer_orders', 'transfer_order_items');


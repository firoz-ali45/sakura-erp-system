-- Simple SQL to Create/Update Suppliers Table
-- Run this SQL in Supabase SQL Editor
-- This will work even if table exists or doesn't exist

-- Step 1: Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 2: Drop and recreate table (ONLY if you don't have important data)
-- If you have data, skip this step and go to Step 3
-- DROP TABLE IF EXISTS suppliers CASCADE;

-- Step 3: Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    name_localized TEXT,
    code TEXT,
    contact_name TEXT,
    phone TEXT,
    primary_email TEXT,
    additional_emails TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    postal_code TEXT,
    tax_id TEXT,
    payment_terms INTEGER DEFAULT 30,
    credit_limit NUMERIC DEFAULT 0,
    currency TEXT DEFAULT 'SAR',
    website TEXT,
    notes TEXT,
    deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 4: Add missing columns one by one (safe - won't error if column exists)
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS name_localized TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS code TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS primary_email TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS additional_emails TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS country TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS postal_code TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS tax_id TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS payment_terms INTEGER DEFAULT 30;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS credit_limit NUMERIC DEFAULT 0;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'SAR';
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Step 5: Set default values for existing rows where name is NULL
UPDATE suppliers SET name = 'Unnamed Supplier' WHERE name IS NULL;

-- Step 6: Make name NOT NULL (only if all rows have name now)
-- This will fail if any row has NULL name, so we set defaults first
DO $$ 
BEGIN
    -- Check if all rows have name
    IF NOT EXISTS (SELECT 1 FROM suppliers WHERE name IS NULL) THEN
        ALTER TABLE suppliers ALTER COLUMN name SET NOT NULL;
    END IF;
END $$;

-- Step 7: Create indexes (only after columns are confirmed to exist)
CREATE INDEX IF NOT EXISTS idx_suppliers_deleted ON suppliers(deleted) WHERE deleted IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_suppliers_deleted_at ON suppliers(deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name) WHERE name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_suppliers_code ON suppliers(code) WHERE code IS NOT NULL;

-- Step 8: Update existing suppliers that have deleted=true but no deleted_at timestamp
UPDATE suppliers 
SET deleted_at = COALESCE(updated_at, created_at, NOW())
WHERE deleted = TRUE AND deleted_at IS NULL;


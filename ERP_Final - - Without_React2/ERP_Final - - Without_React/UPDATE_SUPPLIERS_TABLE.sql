-- Update Suppliers Table to add Soft Delete (deleted_at column) and All Required Columns
-- Run this SQL in Supabase SQL Editor
-- This makes suppliers table structure similar to inventory_items table

-- Ensure created_at column exists (if not exists, add it)
ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Ensure updated_at column exists (if not exists, add it)
ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add deleted_at column for soft delete (if not exists)
ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Ensure deleted column exists (should already exist, but adding for safety)
ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS deleted BOOLEAN DEFAULT FALSE;

-- Add all required columns for suppliers (if not exists)
ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS name_localized TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS code TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS contact_name TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS phone TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS primary_email TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS additional_emails TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS address TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS city TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS state TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS country TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS postal_code TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS tax_id TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS payment_terms INTEGER DEFAULT 30;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS credit_limit NUMERIC DEFAULT 0;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'SAR';

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS website TEXT;

ALTER TABLE suppliers 
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Create index on deleted for faster filtering
CREATE INDEX IF NOT EXISTS idx_suppliers_deleted ON suppliers(deleted);

-- Create index on deleted_at for faster filtering
CREATE INDEX IF NOT EXISTS idx_suppliers_deleted_at ON suppliers(deleted_at);

-- Create index on name for faster searching
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);

-- Create index on code for faster searching
CREATE INDEX IF NOT EXISTS idx_suppliers_code ON suppliers(code);

-- Update existing suppliers that have deleted=true but no deleted_at timestamp
-- Use COALESCE to handle cases where updated_at or created_at might be NULL
UPDATE suppliers 
SET deleted_at = COALESCE(updated_at, created_at, NOW())
WHERE deleted = TRUE AND deleted_at IS NULL;


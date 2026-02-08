-- Create/Update Suppliers Table with Complete Structure
-- Run this SQL in Supabase SQL Editor
-- This creates the suppliers table if it doesn't exist, or adds missing columns

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Check if suppliers table exists
DO $$ 
BEGIN
    -- Create suppliers table if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='suppliers') THEN
        CREATE TABLE suppliers (
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
    END IF;
END $$;

-- Add columns if table already exists but columns are missing (safe to run multiple times)
DO $$ 
BEGIN
    -- Add name if not exists (required column) - MUST be first
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='name') THEN
        ALTER TABLE suppliers ADD COLUMN name TEXT;
        -- Update existing rows to have a default name if null
        UPDATE suppliers SET name = 'Unnamed Supplier' WHERE name IS NULL;
        -- Now make it NOT NULL
        ALTER TABLE suppliers ALTER COLUMN name SET NOT NULL;
    END IF;
    
    -- Add name_localized if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='name_localized') THEN
        ALTER TABLE suppliers ADD COLUMN name_localized TEXT;
    END IF;
    
    -- Add code if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='code') THEN
        ALTER TABLE suppliers ADD COLUMN code TEXT;
    END IF;
    
    -- Add contact_name if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='contact_name') THEN
        ALTER TABLE suppliers ADD COLUMN contact_name TEXT;
    END IF;
    
    -- Add phone if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='phone') THEN
        ALTER TABLE suppliers ADD COLUMN phone TEXT;
    END IF;
    
    -- Add primary_email if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='primary_email') THEN
        ALTER TABLE suppliers ADD COLUMN primary_email TEXT;
    END IF;
    
    -- Add additional_emails if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='additional_emails') THEN
        ALTER TABLE suppliers ADD COLUMN additional_emails TEXT;
    END IF;
    
    -- Add address if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='address') THEN
        ALTER TABLE suppliers ADD COLUMN address TEXT;
    END IF;
    
    -- Add city if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='city') THEN
        ALTER TABLE suppliers ADD COLUMN city TEXT;
    END IF;
    
    -- Add state if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='state') THEN
        ALTER TABLE suppliers ADD COLUMN state TEXT;
    END IF;
    
    -- Add country if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='country') THEN
        ALTER TABLE suppliers ADD COLUMN country TEXT;
    END IF;
    
    -- Add postal_code if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='postal_code') THEN
        ALTER TABLE suppliers ADD COLUMN postal_code TEXT;
    END IF;
    
    -- Add tax_id if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='tax_id') THEN
        ALTER TABLE suppliers ADD COLUMN tax_id TEXT;
    END IF;
    
    -- Add payment_terms if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='payment_terms') THEN
        ALTER TABLE suppliers ADD COLUMN payment_terms INTEGER DEFAULT 30;
    END IF;
    
    -- Add credit_limit if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='credit_limit') THEN
        ALTER TABLE suppliers ADD COLUMN credit_limit NUMERIC DEFAULT 0;
    END IF;
    
    -- Add currency if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='currency') THEN
        ALTER TABLE suppliers ADD COLUMN currency TEXT DEFAULT 'SAR';
    END IF;
    
    -- Add website if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='website') THEN
        ALTER TABLE suppliers ADD COLUMN website TEXT;
    END IF;
    
    -- Add notes if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='notes') THEN
        ALTER TABLE suppliers ADD COLUMN notes TEXT;
    END IF;
    
    -- Add deleted if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='deleted') THEN
        ALTER TABLE suppliers ADD COLUMN deleted BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add deleted_at if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='deleted_at') THEN
        ALTER TABLE suppliers ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add created_at if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='created_at') THEN
        ALTER TABLE suppliers ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
    
    -- Add updated_at if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='updated_at') THEN
        ALTER TABLE suppliers ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Create indexes for better performance (only if columns exist)
DO $$ 
BEGIN
    -- Create index on deleted if column exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='deleted') THEN
        CREATE INDEX IF NOT EXISTS idx_suppliers_deleted ON suppliers(deleted);
    END IF;
    
    -- Create index on deleted_at if column exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='deleted_at') THEN
        CREATE INDEX IF NOT EXISTS idx_suppliers_deleted_at ON suppliers(deleted_at);
    END IF;
    
    -- Create index on name if column exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='name') THEN
        CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);
    END IF;
    
    -- Create index on code if column exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='code') THEN
        CREATE INDEX IF NOT EXISTS idx_suppliers_code ON suppliers(code);
    END IF;
END $$;

-- Update existing suppliers that have deleted=true but no deleted_at timestamp (only if columns exist)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='deleted') 
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='deleted_at')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='updated_at')
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='suppliers' AND column_name='created_at') THEN
        UPDATE suppliers 
        SET deleted_at = COALESCE(updated_at, created_at, NOW())
        WHERE deleted = TRUE AND deleted_at IS NULL;
    END IF;
END $$;


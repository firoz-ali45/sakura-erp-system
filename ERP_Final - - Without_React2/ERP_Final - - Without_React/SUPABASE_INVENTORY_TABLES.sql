-- Supabase Tables for Inventory Items and Categories
-- Run this SQL in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Inventory Categories Table
CREATE TABLE IF NOT EXISTS inventory_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    name_localized TEXT,
    reference TEXT,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inventory Items Table
CREATE TABLE IF NOT EXISTS inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    name_localized TEXT,
    sku TEXT UNIQUE NOT NULL,
    category TEXT,
    storage_unit TEXT NOT NULL,
    ingredient_unit TEXT NOT NULL,
    storage_to_ingredient NUMERIC DEFAULT 1,
    costing_method TEXT NOT NULL,
    cost NUMERIC DEFAULT 0,
    barcode TEXT,
    min_level TEXT,
    max_level TEXT,
    par_level TEXT,
    tags JSONB DEFAULT '[]'::jsonb,
    ingredients JSONB DEFAULT '[]'::jsonb,
    suppliers JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create Indexes
CREATE INDEX IF NOT EXISTS idx_inventory_categories_name ON inventory_categories(name);
CREATE INDEX IF NOT EXISTS idx_inventory_categories_deleted ON inventory_categories(deleted);
CREATE INDEX IF NOT EXISTS idx_inventory_items_sku ON inventory_items(sku);
CREATE INDEX IF NOT EXISTS idx_inventory_items_category ON inventory_items(category);
CREATE INDEX IF NOT EXISTS idx_inventory_items_created_at ON inventory_items(created_at);

-- Enable Row Level Security (Optional - adjust policies as needed)
ALTER TABLE inventory_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all operations for authenticated users (adjust as needed)
CREATE POLICY "Allow all for authenticated users - categories"
    ON inventory_categories
    FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all for authenticated users - items"
    ON inventory_items
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Or for public access (development only):
-- DROP POLICY IF EXISTS "Allow all for authenticated users - categories" ON inventory_categories;
-- DROP POLICY IF EXISTS "Allow all for authenticated users - items" ON inventory_items;

-- CREATE POLICY "Public access - categories"
--     ON inventory_categories
--     FOR ALL
--     USING (true)
--     WITH CHECK (true);

-- CREATE POLICY "Public access - items"
--     ON inventory_items
--     FOR ALL
--     USING (true)
--     WITH CHECK (true);

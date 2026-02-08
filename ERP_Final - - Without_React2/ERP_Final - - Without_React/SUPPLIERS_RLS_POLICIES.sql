-- Suppliers Table RLS Policies
-- Run this SQL in Supabase SQL Editor
-- This enables Row Level Security and creates policies for suppliers table

-- Enable Row Level Security on suppliers table
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Allow all for authenticated users - suppliers" ON suppliers;
DROP POLICY IF EXISTS "Public access - suppliers" ON suppliers;
DROP POLICY IF EXISTS "Enable read access for all users" ON suppliers;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON suppliers;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON suppliers;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON suppliers;

-- Policy 1: Allow SELECT (read) for all users
-- This allows anyone to read suppliers data
CREATE POLICY "Enable read access for all users"
  ON suppliers FOR SELECT
  USING (true);

-- Policy 2: Allow INSERT (create) for all users
-- This allows anyone to insert new suppliers
CREATE POLICY "Enable insert for authenticated users"
  ON suppliers FOR INSERT
  WITH CHECK (true);

-- Policy 3: Allow UPDATE (edit) for all users
-- This allows anyone to update suppliers
CREATE POLICY "Enable update for authenticated users"
  ON suppliers FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Policy 4: Allow DELETE (soft delete) for all users
-- This allows anyone to soft delete suppliers
CREATE POLICY "Enable delete for authenticated users"
  ON suppliers FOR DELETE
  USING (true);

-- Verify policies are created
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'suppliers';


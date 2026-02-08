# Fix GRN Number NULL Constraint - Quick Guide

## Problem
The database has a `NOT NULL` constraint on `grn_number` column, but we need to allow `NULL` for draft GRNs (to show "Draft" instead of a number).

## Solution
Run the SQL script `FIX_GRN_NUMBER_NULL_CONSTRAINT.sql` in Supabase SQL Editor.

## Steps

### Option 1: Using Cursor SQLTools (Recommended)
1. Open Cursor
2. Open SQLTools panel (if not visible, press `Ctrl+Shift+P` and search "SQLTools: Show SQLTools")
3. Right-click on "Supabase ERP" connection → "Connect"
4. Click "New Query" button
5. Open `FIX_GRN_NUMBER_NULL_CONSTRAINT.sql` file
6. Copy all SQL content
7. Paste into the query editor
8. Click "Run on active connection" or press `Ctrl+Enter`
9. Wait for success message

### Option 2: Using Supabase Dashboard
1. Go to https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf/sql/new
2. Open `FIX_GRN_NUMBER_NULL_CONSTRAINT.sql` file
3. Copy all SQL content
4. Paste into Supabase SQL Editor
5. Click "Run" button
6. Wait for success message

## What This Script Does
1. ✅ Removes `NOT NULL` constraint from `grn_number` column
2. ✅ Drops the old UNIQUE constraint
3. ✅ Creates a partial unique index that:
   - Allows multiple `NULL` values (for draft GRNs)
   - Enforces uniqueness only for non-NULL values (actual GRN numbers)

## Expected Result
- ✅ Draft GRNs can have `grn_number = NULL`
- ✅ GRN numbers will be unique when generated (after "Submit for Inspection")
- ✅ Multiple draft GRNs can coexist with `NULL` grn_number
- ✅ GRN creation will work without errors
- ✅ Navigation to GRN detail page will work after creation

## Verification
After running the script, you should see:
- `✅ GRN number constraint fixed successfully!`
- `Draft GRNs can now have grn_number = NULL`
- `GRN numbers will be unique when generated`

## Next Steps
1. Run the SQL script
2. Refresh your browser
3. Try creating a GRN from a Purchase Order
4. It should now work and redirect to GRN detail page!

# GRN Tables Setup Instructions

## ⚠️ IMPORTANT: Table Names

**Correct Table Names:**
- `grn_inspections` (NOT `grns`)
- `grn_inspection_items` (NOT `grn_items`)

## 📋 Steps to Create GRN Tables in Supabase

### Step 1: Open Supabase SQL Editor
1. Go to your Supabase Dashboard
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**

### Step 2: Run CREATE_GRN_TABLES.sql
1. Open the file: `CREATE_GRN_TABLES.sql`
2. Copy the entire SQL code
3. Paste it into Supabase SQL Editor
4. Click **Run** button

### Step 3: Verify Tables Created
After running the SQL, you should see:
- ✅ `grn_inspections` table created
- ✅ `grn_inspection_items` table created
- ✅ Indexes created
- ✅ RLS policies enabled

### Step 4: Check Table Structure
In Supabase Table Editor, you should see:
- **Table:** `grn_inspections` (NOT `grns`)
- **Table:** `grn_inspection_items` (NOT `grn_items`)

## 🔍 How to Check if Tables Exist

1. Go to Supabase Dashboard → **Table Editor**
2. Look for `grn_inspections` in the table list
3. If you see `grns` instead, you need to:
   - Run `CREATE_GRN_TABLES.sql` to create the correct tables
   - OR rename `grns` to `grn_inspections` (not recommended)

## ❌ Common Issues

### Issue 1: Table `grns` exists but `grn_inspections` doesn't
**Solution:** Run `CREATE_GRN_TABLES.sql` - it will create the correct tables.

### Issue 2: Error "relation does not exist"
**Solution:** Make sure you've run `CREATE_GRN_TABLES.sql` in Supabase SQL Editor.

### Issue 3: GRN data not saving
**Solution:** 
1. Check if tables exist: `grn_inspections` and `grn_inspection_items`
2. Check RLS policies are enabled
3. Check console for specific error messages

## ✅ After Tables Are Created

Once the tables are created:
1. ✅ GRN data will save to `grn_inspections` table
2. ✅ GRN items will save to `grn_inspection_items` table
3. ✅ PO approval will auto-create GRN draft
4. ✅ Redirect to GRN main page will work

## 📝 Table Structure

### `grn_inspections` Table:
- `id` (UUID, Primary Key)
- `grn_number` (TEXT, UNIQUE, NOT NULL)
- `purchase_order_id` (UUID, Foreign Key)
- `supplier_id` (UUID, Foreign Key)
- `status` (TEXT: 'draft', 'pending', 'passed', 'hold', 'rejected', 'conditional')
- `grn_date` (TIMESTAMP)
- `inspection_date` (TIMESTAMP)
- ... and more fields

### `grn_inspection_items` Table:
- `id` (UUID, Primary Key)
- `grn_inspection_id` (UUID, Foreign Key)
- `item_id` (UUID)
- `received_quantity` (NUMERIC)
- `ordered_quantity` (NUMERIC)
- ... and more fields


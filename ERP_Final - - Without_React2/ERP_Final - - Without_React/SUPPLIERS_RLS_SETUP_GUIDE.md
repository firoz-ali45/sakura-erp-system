# 🔐 Suppliers Table RLS Policies Setup Guide

## 📋 **Step-by-Step Instructions**

### **Step 1: Supabase Dashboard Mein Login Karein**

1. Browser mein jayein: https://supabase.com/dashboard
2. Apna project select karein (ya create karein agar nahi hai)
3. Login karein

---

### **Step 2: SQL Editor Mein Jao**

1. Left sidebar mein **"SQL Editor"** option click karein
   - Ya direct URL: `https://supabase.com/dashboard/project/YOUR_PROJECT_ID/sql/new`
2. **"New query"** button click karein (agar koi query already open hai to)

---

### **Step 3: SQL Code Copy Karein**

Neeche diya hua SQL code copy karein:

```sql
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
```

---

### **Step 4: SQL Editor Mein Paste Karein**

1. SQL Editor mein paste karein (Ctrl+V ya Right-click → Paste)
2. Code properly paste hua hai verify karein

---

### **Step 5: SQL Run Karein**

1. **"Run"** button click karein (top right corner mein)
   - Ya **Ctrl+Enter** press karein
   - Ya **F5** press karein

---

### **Step 6: Success Verify Karein**

Agar sab sahi hai, to aapko yeh dikhega:

✅ **Success Message:**
```
Success. No rows returned
```

Ya phir **"Query returned successfully"** message

Agar koi error aaye, to:

❌ **Common Errors:**

1. **"relation 'suppliers' does not exist"**
   - **Fix:** Pehle `CREATE_SUPPLIERS_TABLE_SIMPLE.sql` run karein

2. **"policy already exists"**
   - **Fix:** Yeh normal hai, SQL automatically existing policies drop kar deta hai

3. **"permission denied"**
   - **Fix:** Apne project ke admin account se login karein

---

### **Step 7: Policies Verify Karein**

SQL run karne ke baad, last query (SELECT statement) se policies verify ho jayengi.

Agar aapko manually verify karna ho, to:

1. Supabase Dashboard → **"Table Editor"** → **"suppliers"** table
2. **"Policies"** tab click karein
3. Aapko 4 policies dikhni chahiye:
   - ✅ Enable read access for all users (SELECT)
   - ✅ Enable insert for authenticated users (INSERT)
   - ✅ Enable update for authenticated users (UPDATE)
   - ✅ Enable delete for authenticated users (DELETE)

---

## ✅ **Complete!**

Ab aapka suppliers table:
- ✅ RLS enabled hai
- ✅ SELECT policy active hai
- ✅ INSERT policy active hai
- ✅ UPDATE policy active hai
- ✅ DELETE policy active hai

**Ab suppliers import kaam karega!** 🎉

---

## 🔍 **Visual Guide (Screenshots Locations)**

1. **SQL Editor Location:**
   - Left sidebar → "SQL Editor" icon (database icon ke neeche)

2. **Run Button:**
   - Top right corner → Green "Run" button
   - Ya keyboard shortcut: **Ctrl+Enter**

3. **Success Message:**
   - Bottom panel mein "Success" message dikhega

---

## 🆘 **Troubleshooting**

### **Problem: SQL Editor nahi dikh raha**
- **Solution:** Left sidebar expand karein, "SQL Editor" option search karein

### **Problem: "Run" button disabled hai**
- **Solution:** SQL code properly paste karein, syntax check karein

### **Problem: Error: "syntax error"**
- **Solution:** SQL code properly copy karein, extra characters check karein

### **Problem: Policies create nahi ho rahi**
- **Solution:** Pehle verify karein ki `suppliers` table exist karti hai

---

## 📝 **Quick Reference**

**File Location:** `ERP_Final - - Without_React/SUPPLIERS_RLS_POLICIES.sql`

**What it does:**
1. Enables RLS on suppliers table
2. Drops old policies (if any)
3. Creates 4 new policies (SELECT, INSERT, UPDATE, DELETE)
4. Verifies policies are created

**Time Required:** 2-3 minutes

**Difficulty:** Easy ⭐


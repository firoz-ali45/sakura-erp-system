# ⚡ Quick Start - Supabase Automation

## 🎯 **Goal**: Cursor se directly Supabase database manage karna (No Manual Work!)

---

## 🚀 **3 Simple Steps**

### **STEP 1: Setup (Ek Baar)**

```powershell
# Project folder mein jao
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React"

# Setup script run karo
.\setup-supabase-automation.bat
```

**Ye automatically:**
- ✅ Supabase CLI install karega
- ✅ Verification karega

---

### **STEP 2: Project Link (Ek Baar)**

```powershell
# Login (browser open hoga)
npx supabase@latest login

# Project link (apna project reference ID)
npx supabase@latest link --project-ref kexwnurwavszvmlpifsf
```

**Project Reference ID kahan se milega:**

**Method 1: Supabase Dashboard (Recommended)**
1. https://supabase.com/dashboard par jao
2. Apna project select karo
3. **Settings** (⚙️) → **General** tab
4. **Reference ID** copy karo (e.g., `kexwnurwavszvmlpifsf`)

**Method 2: Codebase se (Quick)**
- File: `sakura-erp-migration/frontend/src/services/supabase.js`
- Line: `const SUPABASE_URL = 'https://kexwnurwavszvmlpifsf.supabase.co';`
- Yahan se ID: `kexwnurwavszvmlpifsf` ✅

**Method 3: Browser URL se**
- Dashboard URL: `https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf`
- `/project/` ke baad jo string hai, wahi Reference ID hai

**📖 Detailed Guide:** `HOW_TO_FIND_PROJECT_REF_ID.md` file dekho

---

### **STEP 3: Use Automation (Har Baar)**

**Option A: Using Batch Script (Easiest)**
```powershell
# Example: GRN approval columns add karna
.\run-supabase-migration-npx.bat ADD_GRN_APPROVAL_COLUMNS.sql
```

**Option B: Using PowerShell Script (More Reliable)**
```powershell
# First time: .env file mein DATABASE_URL add karo
# Then:
.\run-sql-direct.ps1 ADD_GRN_APPROVAL_COLUMNS.sql
```

**Option C: Direct Supabase CLI (npx)**
```powershell
# Cursor terminal mein:
npx supabase@latest db execute --file ADD_GRN_APPROVAL_COLUMNS.sql --linked
```

**That's it! 🎉**

---

## 📝 **Example Workflow**

**Scenario: Naya column add karna hai**

1. **SQL file create karo:**
   ```sql
   -- ADD_NEW_COLUMN.sql
   ALTER TABLE grn_inspections 
   ADD COLUMN IF NOT EXISTS new_column TEXT;
   ```

2. **Run karo:**
   ```powershell
   .\run-supabase-migration-npx.bat ADD_NEW_COLUMN.sql
   ```

3. **Done! ✅** Column automatically add ho gaya!

---

## 🔧 **Cursor Extension (Optional - Database Viewer)**

**Cursor mein database directly dekhne ke liye:**

1. **Extensions** (Ctrl+Shift+X)
2. **"PostgreSQL"** ya **"Database Client"** install karo
3. **Connection:**
   - Host: `db.kexwnurwavszvmlpifsf.supabase.co`
   - Port: `5432`
   - Database: `postgres`
   - Username: `postgres`
   - Password: (Supabase database password)

**Ab Cursor mein:**
- ✅ Tables dekh sakte ho
- ✅ Data edit kar sakte ho
- ✅ Queries run kar sakte ho

---

## ✅ **Benefits**

1. ✅ **No Manual Work** - SQL files automatically run
2. ✅ **Cursor Integration** - Cursor se directly access
3. ✅ **Error Handling** - Automatic error checking
4. ✅ **Version Control** - SQL files git mein track
5. ✅ **Team Collaboration** - Sab same migrations use kar sakte hain

---

## 🆘 **Help**

**Problem: "Supabase CLI not found"**
- **Solution:** `npx` use karein (installation ki zarurat nahi)
- ```powershell
  npx supabase@latest --version
  ```

**Problem: "Project not linked"**
```powershell
npx supabase@latest login
npx supabase@latest link --project-ref YOUR_PROJECT_REF
```
- **Project Reference ID kahan se:** `HOW_TO_FIND_PROJECT_REF_ID.md` dekho

---

## 🎉 **Ab Aap:**

- ✅ Manually Supabase dashboard mein kuch nahi karna padega
- ✅ SQL files directly Cursor se run kar sakte ho
- ✅ Database changes automatically apply ho jayengi
- ✅ Errors automatically check ho jayengi

**Happy Coding! 🚀**


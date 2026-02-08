# 🚀 Supabase Automation Setup - Cursor से Direct Connection

## ✅ **Solution: Supabase CLI + Automation Scripts**

Cursor को Supabase से directly connect करने के लिए ye setup karein:

---

## 📋 **STEP 1: Supabase CLI Install Karein**

**Option A: Automated Setup (Recommended)**
```powershell
# Setup script run karein
.\setup-supabase-automation.bat
```

**Option B: Manual Setup**
```powershell
# Supabase CLI install
npm install -g supabase

# Verify installation
supabase --version
```

---

## 📋 **STEP 2: Supabase Project Link Karein**

**PowerShell mein project folder mein:**

```powershell
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React"

# Supabase login (browser mein login hoga)
supabase login

# Project link (apna project reference ID use karein)
supabase link --project-ref kexwnurwavszvmlpifsf
```

**Note:** `kexwnurwavszvmlpifsf` ko apne actual Supabase project reference ID se replace karein.

**Project Reference ID kahan se milega:**
1. Supabase Dashboard → Settings → General
2. "Reference ID" copy karein

---

## 📋 **STEP 3: Automated Migration Run Karein**

**Ab SQL files automatically run ho jayengi!**

```powershell
# Kisi bhi SQL file ko run karein
.\run-supabase-migration.bat ADD_GRN_APPROVAL_COLUMNS.sql

# Ya koi bhi SQL file
.\run-supabase-migration.bat CREATE_GRN_TABLES.sql
```

**Ye script:**
- ✅ SQL file ko automatically Supabase database mein run karega
- ✅ Errors check karega
- ✅ Success/failure message dikhayega
- ✅ Manual Supabase dashboard ki zarurat nahi!

---

## 📋 **STEP 4: Cursor Extension Setup (Optional - Database Viewer)**

**Cursor mein database directly dekhne ke liye:**

1. **Cursor Extensions** open karein (Ctrl+Shift+X)
2. **"PostgreSQL"** ya **"Database Client"** extension install karein
3. **Connection setup:**
   - Host: `db.kexwnurwavszvmlpifsf.supabase.co`
   - Port: `5432`
   - Database: `postgres`
   - Username: `postgres`
   - Password: (apna Supabase database password)

**Ab Cursor mein:**
- ✅ Tables directly dekh sakte hain
- ✅ Data edit kar sakte hain
- ✅ Queries run kar sakte hain
- ✅ Schema changes dekh sakte hain

---

## 📋 **STEP 5: Environment Variables Setup**

**`.env` file create karein (project root mein):**

```env
# Supabase Connection
SUPABASE_URL=https://kexwnurwavszvmlpifsf.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# Database Direct Connection (for migrations)
DATABASE_URL=postgresql://postgres:[YOUR_PASSWORD]@db.kexwnurwavszvmlpifsf.supabase.co:5432/postgres
```

**Supabase Dashboard se keys copy karein:**
1. Settings → API
2. Project URL copy karein
3. `anon` key copy karein
4. `service_role` key copy karein (secret!)

---

## 🎯 **Usage Examples**

### **Example 1: New Column Add Karna**

```powershell
# SQL file create karein: ADD_NEW_COLUMN.sql
# Then run:
.\run-supabase-migration.bat ADD_NEW_COLUMN.sql
```

### **Example 2: Multiple Migrations**

```powershell
# Ek saath multiple files run karein
.\run-supabase-migration.bat ADD_GRN_APPROVAL_COLUMNS.sql
.\run-supabase-migration.bat CREATE_GRN_TABLES.sql
.\run-supabase-migration.bat FIX_GRN_CONSTRAINTS.sql
```

### **Example 3: Cursor se Direct**

**Cursor mein terminal open karein aur:**
```powershell
supabase db execute --file ADD_GRN_APPROVAL_COLUMNS.sql
```

---

## 🔧 **Troubleshooting**

### **Problem: "Supabase CLI not found"**
**Solution:**
```powershell
npm install -g supabase
```

### **Problem: "Project not linked"**
**Solution:**
```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

### **Problem: "Permission denied"**
**Solution:**
- Supabase Dashboard → Settings → Database
- Check database password
- Update `.env` file with correct password

---

## ✅ **Benefits**

1. ✅ **No Manual Work**: SQL files automatically run ho jayengi
2. ✅ **Cursor Integration**: Cursor se directly database access
3. ✅ **Error Handling**: Automatic error checking
4. ✅ **Version Control**: SQL files git mein track ho sakti hain
5. ✅ **Team Collaboration**: Sab developers same migrations use kar sakte hain

---

## 📝 **Next Steps**

1. ✅ `setup-supabase-automation.bat` run karein
2. ✅ `supabase login` aur `supabase link` karein
3. ✅ `run-supabase-migration.bat ADD_GRN_APPROVAL_COLUMNS.sql` test karein
4. ✅ Cursor PostgreSQL extension install karein (optional)

**Ab aap manually Supabase dashboard mein kuch nahi karna padega! 🎉**

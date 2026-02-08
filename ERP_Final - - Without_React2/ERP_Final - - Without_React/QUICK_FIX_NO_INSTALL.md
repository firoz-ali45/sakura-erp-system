# ⚡ Quick Fix - Supabase CLI Installation Problem

## ❌ **Problem:**
```
Installing Supabase CLI as a global module is not supported.
```

## ✅ **Solution: Use npx (No Installation Needed!)**

Supabase CLI ko install kiye **BINA** bhi use kar sakte ho!

---

## 🚀 **Quick Start (3 Steps)**

### **STEP 1: Login (Ek Baar)**

```powershell
npx supabase@latest login
```

**Browser open hoga, login karo!**

---

### **STEP 2: Project Link (Ek Baar)**

```powershell
npx supabase@latest link --project-ref kexwnurwavszvmlpifsf
```

**Note:** `kexwnurwavszvmlpifsf` ko apne actual project reference ID se replace karo.

---

### **STEP 3: Run Migrations (Har Baar)**

**Option A: Using Batch Script (Easiest)**
```powershell
.\run-supabase-migration-npx.bat ADD_GRN_APPROVAL_COLUMNS.sql
```

**Option B: Direct Command**
```powershell
npx supabase@latest db execute --file ADD_GRN_APPROVAL_COLUMNS.sql --linked
```

---

## 📋 **Complete Workflow Example**

```powershell
# 1. Login (ek baar)
npx supabase@latest login

# 2. Link project (ek baar)
npx supabase@latest link --project-ref kexwnurwavszvmlpifsf

# 3. Run any SQL file
npx supabase@latest db execute --file ADD_GRN_APPROVAL_COLUMNS.sql --linked
npx supabase@latest db execute --file CREATE_GRN_TABLES.sql --linked
```

---

## ✅ **Benefits of npx Method:**

1. ✅ **No Installation** - Kuch install nahi karna padega
2. ✅ **Always Latest** - Latest version automatically use hoga
3. ✅ **No Admin Rights** - Admin rights ki zarurat nahi
4. ✅ **Works Everywhere** - Kisi bhi machine par kaam karega

---

## 🔧 **Alternative: Manual Installation (If Needed)**

### **Option 1: Scoop (Recommended for Windows)**

```powershell
# PowerShell (Admin) mein:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Phir:
scoop install supabase
```

### **Option 2: Chocolatey**

```powershell
# Chocolatey install karo: https://chocolatey.org/install
# Phir:
choco install supabase -y
```

### **Option 3: Direct Download**

1. Visit: https://github.com/supabase/cli/releases
2. Latest release download karo
3. Extract aur PATH mein add karo

---

## 🎯 **Recommended: Use npx Method**

**Sabse aasaan: npx use karo!**

```powershell
# Ek baar setup:
npx supabase@latest login
npx supabase@latest link --project-ref kexwnurwavszvmlpifsf

# Phir har baar:
.\run-supabase-migration-npx.bat ADD_GRN_APPROVAL_COLUMNS.sql
```

**That's it! No installation needed! 🎉**



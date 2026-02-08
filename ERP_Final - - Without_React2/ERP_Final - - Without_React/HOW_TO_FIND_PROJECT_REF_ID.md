# 🔍 Project Reference ID कहाँ से मिलेगा?

## ✅ **Method 1: Supabase Dashboard से (Recommended)**

### **Step-by-Step:**

1. **Browser kholo aur Supabase Dashboard kholo:**
   - https://supabase.com/dashboard par jao
   - Login karo (agar nahi logged in ho)

2. **Apna Project Select Karo:**
   - Dashboard mein apne project ka naam click karo
   - Ya phir left sidebar se project select karo

3. **Settings Menu Kholo:**
   - **Left sidebar** mein **Settings** (⚙️ gear icon) par click karo

4. **General Tab Mein Jao:**
   - Settings page open hone ke baad
   - **"General"** tab par click karo (pehle se selected ho sakta hai)

5. **Reference ID Copy Karo:**
   - Page scroll karo
   - **"Reference ID"** section dikhega
   - Wahan ek long string dikhegi, jaise: `kexwnurwavszvmlpifsf`
   - **Copy button** click karke ya manually select karke copy karo

---

## ✅ **Method 2: Project URL से (Quick Method)**

Agar aapko Supabase dashboard URL pata hai, to:

1. **Browser address bar mein dekho:**
   ```
   https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf
   ```
   
2. **URL mein `/project/` ke baad jo string hai, wahi Project Reference ID hai:**
   - Example: `kexwnurwavszvmlpifsf` ✅

---

## ✅ **Method 3: Codebase Mein Check Karo (Already Set Hai!)**

Aapke codebase mein already project reference ID set hai:

**File:** `sakura-erp-migration/frontend/src/services/supabase.js`

```javascript
const SUPABASE_URL = 'https://kexwnurwavszvmlpifsf.supabase.co';
```

**Yahan se Project Reference ID:** `kexwnurwavszvmlpifsf` ✅

---

## 🚀 **Ab Command Mein Use Kaise Karein?**

### **Step 1: Cursor Terminal Kholo**

1. Cursor mein **Terminal** kholo (Ctrl + `)
2. Ya phir **View → Terminal**

### **Step 2: Project Root Folder Mein Jao**

```powershell
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React2\ERP_Final - - Without_React"
```

### **Step 3: Login Karein (Pehli Baar)**

```powershell
npx supabase@latest login
```

- Ye command browser khol dega
- Wahan Supabase account se login karo
- Login successful hone ke baad terminal mein message dikhega

### **Step 4: Project Link Karein**

```powershell
npx supabase@latest link --project-ref kexwnurwavszvmlpifsf
```

**Important:** 
- `kexwnurwavszvmlpifsf` ko apne actual project reference ID se replace karein (agar different hai)
- Agar aapke codebase mein same ID hai (`kexwnurwavszvmlpifsf`), to directly use kar sakte hain

**Expected Output:**
```
✓ Linked to project kexwnurwavszvmlpifsf
```

---

## ✅ **Verification: Project Link Ho Gaya?**

Link successful hone ke baad, aapke project folder mein `.supabase/config.toml` file create hogi.

**Check karne ke liye:**

```powershell
# Check if config file exists
dir .supabase\config.toml
```

Agar file dikhe, to project successfully link ho gaya hai! ✅

---

## 🎯 **Complete Example Workflow**

```powershell
# Step 1: Project folder mein jao
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React2\ERP_Final - - Without_React"

# Step 2: Login (pehli baar)
npx supabase@latest login

# Step 3: Project link (pehli baar)
npx supabase@latest link --project-ref kexwnurwavszvmlpifsf

# Step 4: Ab SQL files run kar sakte ho
.\run-supabase-migration-npx.bat ADD_GRN_APPROVAL_COLUMNS.sql
```

---

## ❓ **FAQ**

### **Q: Project Reference ID kya hai?**
**A:** Ye aapke Supabase project ka unique identifier hai. Har project ka apna unique ID hota hai.

### **Q: Kya main apne codebase se directly use kar sakta hoon?**
**A:** Haan! Agar aapke `supabase.js` file mein jo URL hai, usmein jo ID hai (`kexwnurwavszvmlpifsf`), wahi use karein. Bas verify kar lein ki Supabase dashboard mein bhi same ID hai.

### **Q: Agar different project use karna ho?**
**A:** To Supabase dashboard se naye project ka Reference ID copy karke use karein.

### **Q: Link command fail ho raha hai?**
**A:** 
1. Pehle `npx supabase@latest login` run karein
2. Browser mein successfully login ho jao
3. Phir `link` command run karein

---

## 🎉 **Done!**

Ab aap project link kar chuke hain. Ab SQL migrations directly run kar sakte ho:

```powershell
.\run-supabase-migration-npx.bat YOUR_SQL_FILE.sql
```

# 📍 Setup Script कहाँ Run करें?

## ✅ **Location: Project Root Folder**

**File path:**
```
C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\setup-supabase-automation.bat
```

---

## 🚀 **3 तरीके Run करने के:**

### **Method 1: Double-Click (सबसे आसान) ✅**

1. **File Explorer** खोलें
2. **Project folder** में जाएं:
   ```
   C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React
   ```
3. **`setup-supabase-automation.bat`** file को **double-click** करें
4. **PowerShell window** खुलेगी
5. **Setup automatically** हो जाएगा

---

### **Method 2: Cursor Terminal से (Recommended) ✅**

1. **Cursor** में project folder खोलें
2. **Terminal** खोलें (Ctrl + ` या View → Terminal)
3. **Command run करें:**
   ```powershell
   .\setup-supabase-automation.bat
   ```
4. **Setup complete** होने तक wait करें

---

### **Method 3: PowerShell से Directly**

1. **PowerShell** खोलें (Windows + X → Windows PowerShell)
2. **Project folder** में navigate करें:
   ```powershell
   cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React"
   ```
3. **Script run करें:**
   ```powershell
   .\setup-supabase-automation.bat
   ```

---

## 📋 **Setup के बाद क्या होगा:**

1. ✅ **Supabase CLI install** हो जाएगा
2. ✅ **Verification** message दिखेगा
3. ✅ **Next steps** instructions दिखेंगी

---

## ⚠️ **Important Notes:**

1. **Internet connection** होना चाहिए (npm install के लिए)
2. **Node.js** installed होना चाहिए
3. **Admin rights** की जरूरत हो सकती है (global install के लिए)

---

## 🔍 **Check करें कि Script सही Location में है:**

**File Explorer में देखें:**
```
ERP_Final - - Without_React\
  ├── setup-supabase-automation.bat  ← यहाँ होना चाहिए
  ├── run-supabase-migration.bat
  ├── ADD_GRN_APPROVAL_COLUMNS.sql
  └── ... (other files)
```

---

## 🆘 **Problem होने पर:**

**Error: "Node.js not found"**
- Node.js install करें: https://nodejs.org

**Error: "Permission denied"**
- PowerShell को **Run as Administrator** से खोलें

**Error: "npm not found"**
- Node.js reinstall करें

---

## ✅ **Setup Complete होने के बाद:**

**Next steps:**
```powershell
# 1. Login
supabase login

# 2. Link project
supabase link --project-ref kexwnurwavszvmlpifsf

# 3. Test migration
.\run-supabase-migration.bat ADD_GRN_APPROVAL_COLUMNS.sql
```

---

**सबसे आसान: File Explorer में double-click करें! 🎯**



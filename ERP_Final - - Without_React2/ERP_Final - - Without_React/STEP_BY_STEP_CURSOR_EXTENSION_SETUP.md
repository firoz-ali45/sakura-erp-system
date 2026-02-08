# 🚀 Step-by-Step: Cursor Extension Setup (SQLTools)

## 📋 **STEP 1: Extension Install Karein**

### **Method A: Cursor Extensions Panel Se (Easiest)**

1. **Cursor kholo**
2. **Extensions panel kholo:**
   - **Keyboard Shortcut:** `Ctrl + Shift + X`
   - Ya phir **Left sidebar** mein **Extensions** icon click karo (4 boxes ka icon)
3. **Search box mein type karo:**
   ```
   SQLTools
   ```
4. **"SQLTools" by Matheus Teixeira** dikhega
5. **"Install"** button click karo
6. **Installation complete hone ka wait karo**

### **Method B: Direct Link Se**

1. Cursor mein **Command Palette** kholo:
   - **Keyboard Shortcut:** `Ctrl + Shift + P`
2. Type karo: `Extensions: Install Extensions`
3. Search box mein: `SQLTools`
4. Install karo

---

## 📋 **STEP 2: PostgreSQL Driver Install Karein**

**Important:** SQLTools ke saath PostgreSQL driver bhi install karna zaroori hai!

1. **Extensions panel** mein hi raho
2. **Search karo:**
   ```
   SQLTools PostgreSQL
   ```
3. **"SQLTools Driver - PostgreSQL"** by Matheus Teixeira dikhega
4. **"Install"** button click karo
5. **Installation complete hone ka wait karo**

---

## 📋 **STEP 3: Cursor Restart Karein (Optional but Recommended)**

1. **Cursor close karo** (File → Exit)
2. **Phir se kholo**
3. Ye ensure karega ki extensions properly load ho jayen

---

## 📋 **STEP 4: SQLTools Panel Kholo**

1. **Left sidebar** mein **SQLTools** icon dikhega
   - Icon: Database/server ka symbol hoga
2. **Click karo** to open SQLTools panel
3. Agar icon nahi dikhe, to:
   - **View** → **Open View...** → **SQLTools** select karo

---

## 📋 **STEP 5: Connection Add Karein**

### **Step 5.1: Add New Connection**

1. **SQLTools panel** mein (left sidebar)
2. **"Add New Connection"** button click karo
   - Ya phir **right-click** → **"Add New Connection"**
   - Ya phir **"+"** icon click karo

### **Step 5.2: Connection Type Select Karein**

1. **Connection type** dropdown se **"PostgreSQL"** select karo
2. **"Next"** ya **"Continue"** click karo

### **Step 5.3: Connection Details Fill Karein**

**Form mein ye details fill karo:**

```
Connection Name: Supabase ERP
  (Ya koi bhi naam jo aapko pasand ho)

Server/Host: db.kexwnurwavszvmlpifsf.supabase.co
  (Ye Supabase database host hai)

Port: 5432
  (Default PostgreSQL port)

Database: postgres
  (Default database name)

Username: postgres
  (Default Supabase username)

Password: [YOUR_SUPABASE_DATABASE_PASSWORD]
  (Ye important hai - neeche dekho kahan se milega)
```

### **Step 5.4: Password Kahan Se Milega?**

**Option 1: Supabase Dashboard Se**

1. Browser mein jao: https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf
2. **Settings** (⚙️ gear icon) → **Database**
3. **Connection string** section mein
4. **URI** tab select karo
5. Connection string dikhega:
   ```
   postgresql://postgres:[YOUR-PASSWORD]@db.kexwnurwavszvmlpifsf.supabase.co:5432/postgres
   ```
6. `[YOUR-PASSWORD]` wahi hai jo aapko chahiye
   - Agar password yaad nahi hai, to **"Reset Database Password"** option use karo

**Option 2: Project Create Karte Waqt**

- Agar aapne project create karte waqt password set kiya tha, wahi use karo

### **Step 5.5: Test Connection**

1. **"Test Connection"** button click karo
2. Agar **"Connection successful"** dikhe, to:
   - ✅ **"Save"** ya **"OK"** click karo
3. Agar error aaye, to:
   - Password check karo
   - Server address check karo
   - Internet connection check karo

---

## 📋 **STEP 6: Connection Use Karein**

### **Step 6.1: Connection Expand Karo**

1. **SQLTools panel** mein
2. **"Supabase ERP"** connection dikhega
3. **Expand karo** (arrow click karo)
4. **"Tables"** folder dikhega

### **Step 6.2: Tables Dekho**

1. **"Tables"** folder expand karo
2. **Sab tables dikhengi:**
   - `users`
   - `inventory_items`
   - `grn_inspections`
   - `grn_inspection_items`
   - etc.

### **Step 6.3: Table Data Dekho**

1. **Kisi bhi table par right-click** karo
2. **"Show Table Records"** select karo
3. **Data dikhega** (new tab mein)

### **Step 6.4: SQL Query Run Karein**

1. **SQLTools panel** mein
2. **"New Query"** button click karo
   - Ya phir **Ctrl + Shift + Q**
3. **SQL query type karo:**
   ```sql
   SELECT * FROM users LIMIT 10;
   ```
4. **Connection select karo** (dropdown se: "Supabase ERP")
5. **"Run Query"** button click karo
   - Ya phir **Ctrl + Enter**
6. **Results dikhenge**

---

## ✅ **Verification: Sab Kuch Kaam Kar Raha Hai?**

### **Check 1: Connection Active Hai?**

- SQLTools panel mein connection **green** ya **connected** dikhe
- Agar **red** ya **disconnected** dikhe, to **right-click** → **"Connect"**

### **Check 2: Tables Dikhengi?**

- **Tables** folder expand karo
- At least 1-2 tables dikhni chahiye

### **Check 3: Query Run Ho Rahi Hai?**

- Simple query run karo: `SELECT 1;`
- Results aane chahiye

---

## 🆘 **Troubleshooting**

### **Problem 1: Extension Install Nahi Ho Raha**

**Solution:**
- Cursor restart karo
- Internet connection check karo
- Cursor update karo (agar old version hai)

### **Problem 2: Connection Failed**

**Solution:**
- Password double-check karo
- Server address verify karo: `db.kexwnurwavszvmlpifsf.supabase.co`
- Supabase dashboard mein check karo ki project active hai

### **Problem 3: Tables Nahi Dikhengi**

**Solution:**
- Connection refresh karo (right-click → Refresh)
- Database mein tables exist karti hain ya nahi check karo
- Supabase dashboard → Table Editor mein verify karo

### **Problem 4: SQLTools Panel Nahi Dikhe**

**Solution:**
- **View** → **Open View...** → **SQLTools** select karo
- Ya phir **Command Palette** (`Ctrl + Shift + P`) → Type: `SQLTools: Focus on SQLTools View`

---

## 🎯 **Quick Reference**

| Step | Action | Location |
|------|--------|----------|
| 1 | Extension Install | Extensions Panel (Ctrl+Shift+X) |
| 2 | Driver Install | Extensions Panel (SQLTools PostgreSQL) |
| 3 | SQLTools Panel | Left Sidebar (SQLTools icon) |
| 4 | Add Connection | SQLTools Panel → Add New Connection |
| 5 | Fill Details | Connection Form |
| 6 | Test & Save | Test Connection → Save |
| 7 | Use | Expand Connection → Browse Tables |

---

## 🎉 **Done!**

Ab aap Cursor se directly Supabase database access kar sakte ho!

**Next Steps:**
- Tables explore karo
- Data browse karo
- SQL queries run karo
- Schema explore karo

**Happy Coding! 🚀**

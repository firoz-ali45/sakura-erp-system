# pgAdmin Kaise Kholo? (Step by Step)

## Method 1: Start Menu Se (Sabse Easy)

1. **Windows Start Button** click karo (bottom left corner)
2. **Search box** mein type karo: `pgAdmin`
3. **pgAdmin 4** ya **pgAdmin** click karo
4. pgAdmin khul jayega!

## Method 2: Desktop Shortcut Se

Agar desktop par pgAdmin ka shortcut hai, to:
- **pgAdmin** icon par double-click karo

## Method 3: File Explorer Se

1. **File Explorer** kholo
2. Ye path jao:
   ```
   C:\Program Files\PostgreSQL\15\pgAdmin 4
   ```
   (15 ki jagah apna PostgreSQL version ho sakta hai - 14, 16, etc.)
3. **pgAdmin4.exe** file ko double-click karo

## Method 4: Run Command Se

1. **Windows + R** keys press karo (Run dialog khulega)
2. Type karo: `pgAdmin4`
3. **Enter** press karo

## Agar pgAdmin Nahi Mila?

### PostgreSQL Install Nahi Hai?

Agar pgAdmin nahi mila, to PostgreSQL install nahi hai.

**Install karo:**
1. https://www.postgresql.org/download/windows/ par jao
2. "Download the installer" click karo
3. Latest version download karo (15.x ya 16.x)
4. Installer run karo
5. Installation ke time:
   - **Port**: 5432 (default - change mat karo)
   - **Password**: Apna password set karo (yaad rakhna!)
   - **pgAdmin 4** install karna confirm karo (checkbox ticked hona chahiye)
6. Installation complete hone ke baad **pgAdmin 4** automatically install ho jayega

## pgAdmin Kholne Ke Baad Kya Karein?

1. **pgAdmin khul jayega**
2. **Password enter karo** (jo PostgreSQL install ke time set kiya tha)
3. **Left side** par "Servers" dikhega
4. **"PostgreSQL 15"** (ya jo version hai) expand karo
5. **"Databases"** par right-click karo
6. **"Create" → "Database"** click karo
7. **Name**: `sakura_erp` type karo
8. **"Save"** click karo

**Bas! Database ready! ✅**

## Quick Check: PostgreSQL Install Hai Ya Nahi?

**PowerShell mein ye command run karo:**
```powershell
Get-Service -Name postgresql*
```

Agar service dikhe, to PostgreSQL install hai!

---

**Agar abhi bhi problem hai, to batao - main aur help karunga!**



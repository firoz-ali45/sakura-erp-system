# Complete Setup Guide - Step by Step

## ✅ Step 1: pgAdmin Mein Database Create Karein (DONE - Ab Next)

pgAdmin open hai, ab ye karo:

### A. Server Connect Karein (Pehli Baar)

1. **"Add New Server"** button click karo (Quick Links section mein)
2. **"General" tab:**
   - Name: `Local PostgreSQL`
3. **"Connection" tab:**
   - Host: `localhost`
   - Port: `5432`
   - Database: `postgres`
   - Username: `postgres`
   - Password: (apna PostgreSQL password)
4. **"Save"** click karo

### B. Database Create Karein

1. Left side **"Servers"** → **"PostgreSQL 18"** expand karo
2. **"Databases"** par right-click
3. **"Create" → "Database"**
4. Name: `sakura_erp`
5. **"Save"** click karo

**✅ Database ready!**

---

## ✅ Step 2: .env File Update Karein

**IMPORTANT:** Agar apka PostgreSQL password `postgres` nahi hai, to:

1. `backend` folder mein `.env` file kholo
2. `postgres` ko apne actual password se replace karo:
   ```
   DATABASE_URL="postgresql://postgres:[YOUR_PASSWORD]@localhost:5432/sakura_erp"
   ```
3. Save karo

---

## ✅ Step 3: Migrations Run Karein

**Option 1: Batch File Se (Easiest)**
- `RUN_MIGRATIONS.bat` file double-click karo
- Automatically sab ho jayega

**Option 2: Manual (PowerShell)**
```powershell
cd "sakura-erp-migration\backend"

# Dependencies install (pehli baar)
npm install

# Prisma client generate
npm run prisma:generate

# Migrations run (tables create honge)
npm run prisma:migrate
```

---

## ✅ Step 4: Admin User Create Karein

**Prisma Studio se:**

```powershell
cd backend
npm run prisma:studio
```

Browser mein Prisma Studio khulega:
1. **"Users"** table select karo
2. **"Add record"** click karo
3. Fill karo:
   - email: `admin@sakura.com`
   - name: `Admin User`
   - role: `admin`
   - status: `active`
   - password_hash: (see below)

**Password hash generate:**
```powershell
node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('admin123', 10).then(hash => console.log(hash))"
```

Output ko copy karke password_hash field mein paste karo.

---

## ✅ Step 5: ERP Kholo!

**`ERP_KHOLO.bat`** file double-click karo!

- Backend start hoga
- Frontend start hoga
- Browser khul jayega
- Login karo: `admin@sakura.com` / `admin123`

---

**Bas! Sab ready! 🎉**


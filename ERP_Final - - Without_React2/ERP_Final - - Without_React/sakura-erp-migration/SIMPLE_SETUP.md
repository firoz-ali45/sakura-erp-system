# 🚀 Sakura ERP - Simple Setup (Hindi)

## Ek Click Mein Kholo

**`ERP_KHOLO.bat`** file ko double-click karo - bas itna hi!

## Pehli Baar Setup

### 1. PostgreSQL Install Karna Hai

Agar PostgreSQL install nahi hai:
- Download: https://www.postgresql.org/download/windows/
- Install karo
- Password yaad rakhna (default: `postgres`)

### 2. Database Create Karna Hai

**pgAdmin kholo** (PostgreSQL ke saath aata hai):
1. pgAdmin open karo
2. Left side par "Servers" → "PostgreSQL 15" (ya jo version hai)
3. "Databases" par right-click
4. "Create" → "Database"
5. Name: `sakura_erp`
6. "Save" click karo

**Ya phir Query Tool mein:**
```sql
CREATE DATABASE sakura_erp;
```

### 3. Password Check Karo

Agar apka PostgreSQL password `postgres` nahi hai:
1. `backend` folder mein `.env` file kholo
2. `password` ko apne actual password se replace karo
3. Save karo

### 4. ERP Kholo

**`ERP_KHOLO.bat`** file ko double-click karo!

## Kya Hoga?

1. ✅ Dependencies automatically install hongi (pehli baar)
2. ✅ Backend server start hoga (port 3000)
3. ✅ Frontend server start hoga (port 5173)
4. ✅ Browser automatically khul jayega

## Agar Problem Aaye

### "npm install" error?
- Node.js install karo: https://nodejs.org/
- Node.js version 18+ honi chahiye

### "Database connection" error?
- PostgreSQL service running hai check karo
- `.env` file mein correct password hai check karo
- Database `sakura_erp` create ho gaya hai check karo

### "Port already in use" error?
- Port 3000 ya 5173 already use ho raha hai
- Task Manager mein check karo
- Ya computer restart karo

## Admin User Kaise Banayein?

1. Backend terminal mein:
   ```
   npm run prisma:studio
   ```
2. Browser mein Prisma Studio khulega
3. "Users" table select karo
4. "Add record" click karo
5. Ye fill karo:
   - email: `admin@sakura.com`
   - name: `Admin`
   - password_hash: (see below)
   - role: `admin`
   - status: `active`

**Password hash generate karo:**
```powershell
cd backend
node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('admin123', 10).then(hash => console.log(hash))"
```

Output ko copy karke password_hash field mein paste karo.

## Login Credentials

- Email: `admin@sakura.com`
- Password: `admin123` (jo aapne password_hash mein use kiya)

---

**Bas itna hi! Simple hai! 🎉**


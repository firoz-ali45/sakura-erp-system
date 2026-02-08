# 🚀 Sakura ERP - Kaise Start Karein (How to Start)

## 📍 Project Location

Project yahan hai:
```
C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration
```

## ⚡ Quick Start (3 Steps)

### Step 1: Database Setup

**PowerShell mein ye commands run karein:**

```powershell
# PostgreSQL database create karein
createdb sakura_erp

# Ya phir psql se:
psql -U postgres
CREATE DATABASE sakura_erp;
\q
```

### Step 2: Backend Start Karein

**PowerShell Terminal 1:**

```powershell
# Project folder mein jao
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration\backend"

# Dependencies install karein
npm install

# .env file create karein (database connection ke liye)
# .env file mein ye add karein:
# DATABASE_URL="postgresql://postgres:password@localhost:5432/sakura_erp"
# JWT_SECRET="your-secret-key-here"
# PORT=3000
# CORS_ORIGIN="http://localhost:5173"

# Database setup
npm run prisma:generate
npm run prisma:migrate

# Backend start karein
npm run dev
```

Backend `http://localhost:3000` par chalega ✅

### Step 3: Frontend Start Karein

**PowerShell Terminal 2 (naya terminal):**

```powershell
# Frontend folder mein jao
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration\frontend"

# Dependencies install karein
npm install

# Frontend start karein
npm run dev
```

Frontend `http://localhost:5173` par chalega ✅

## 🌐 Browser Mein Kholo

1. Browser kholo
2. Ye URL open karo: **http://localhost:5173**
3. Login page dikhega

## 👤 Admin User Create Karein

**Prisma Studio use karein (easiest way):**

```powershell
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration\backend"
npm run prisma:studio
```

Prisma Studio browser mein khul jayega. Wahan:
1. "Users" table select karo
2. "Add record" button click karo
3. Ye fields fill karo:
   - email: `admin@sakura.com`
   - name: `Admin User`
   - password_hash: (bcrypt hash - see below)
   - role: `admin`
   - status: `active`

**Password hash generate karein:**

```powershell
cd backend
node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('admin123', 10).then(hash => console.log(hash))"
```

Output ko copy karke password_hash field mein paste karo.

## 📂 Important Files Location

- **Backend Code**: `sakura-erp-migration\backend\src\`
- **Frontend Code**: `sakura-erp-migration\frontend\src\`
- **Database Schema**: `sakura-erp-migration\prisma\schema.prisma`
- **API Documentation**: `sakura-erp-migration\API_MAP.md`
- **Deployment Guide**: `sakura-erp-migration\DEPLOYMENT.md`

## ✅ Checklist

- [ ] PostgreSQL installed hai
- [ ] Database `sakura_erp` create ho gaya
- [ ] Backend dependencies install ho gaye
- [ ] Frontend dependencies install ho gaye
- [ ] Backend `localhost:3000` par chal raha hai
- [ ] Frontend `localhost:5173` par chal raha hai
- [ ] Admin user create ho gaya
- [ ] Browser mein login ho gaya

## 🆘 Agar Problem Aaye

**Database connection error?**
- Check karo PostgreSQL service running hai
- `.env` file mein correct DATABASE_URL hai

**Port already in use?**
```powershell
# Port 3000 check karo
netstat -ano | findstr :3000
# Process kill karo (PID use karke)
taskkill /PID <PID> /F
```

**npm install error?**
- Node.js version 18+ hai check karo
- `npm cache clean --force` try karo

## 🎯 Next Steps

1. Login karo admin credentials se
2. Inventory Items module check karo (fully migrated hai)
3. API test karo: `http://localhost:3000/api/health`
4. Documentation padho: `API_MAP.md` aur `MODULE_MAPPING.md`

---

**Happy Coding! 🚀**


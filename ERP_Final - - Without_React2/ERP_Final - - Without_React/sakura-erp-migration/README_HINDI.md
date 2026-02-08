# 🎯 Sakura ERP - Kaise Kholo (Simple Guide)

## ✅ Sabse Simple Tarika

### Step 1: Database Create Karo (Sirf Ek Baar)

**pgAdmin kholo** (PostgreSQL ke saath aata hai):
1. pgAdmin open karo
2. Left side par "Databases" par right-click karo
3. "Create" → "Database" click karo
4. Name: `sakura_erp` type karo
5. "Save" click karo

**Bas! Database ready! ✅**

### Step 2: ERP Kholo

**`ERP_KHOLO.bat`** file ko **double-click** karo!

Kya hoga:
- ✅ Backend automatically start hoga
- ✅ Frontend automatically start hoga  
- ✅ Browser automatically khul jayega
- ✅ ERP dikh jayega!

## 📍 File Kahan Hai?

```
sakura-erp-migration\
  └── ERP_KHOLO.bat  ← YEH FILE DOUBLE-CLICK KARO!
```

## 🔑 Pehli Baar Setup

Agar pehli baar chal rahe ho, to:

1. **Node.js install karo** (agar nahi hai):
   - https://nodejs.org/ se download karo
   - Install karo

2. **PostgreSQL install karo** (agar nahi hai):
   - https://www.postgresql.org/download/windows/
   - Install karo
   - Password yaad rakhna

3. **Database create karo** (upar diya gaya)

4. **ERP_KHOLO.bat** double-click karo!

## ⚠️ Agar Error Aaye

### "npm install" error?
→ Node.js install karo

### "Database connection" error?
→ `.env` file mein password check karo
→ Database `sakura_erp` create ho gaya hai check karo

### "Port already in use"?
→ Computer restart karo
→ Ya Task Manager mein old processes band karo

## 👤 Admin User Kaise Banayein?

1. Backend terminal mein type karo:
   ```
   npm run prisma:studio
   ```

2. Browser mein Prisma Studio khulega

3. "Users" table par click karo

4. "Add record" button click karo

5. Ye fill karo:
   - email: `admin@sakura.com`
   - name: `Admin User`
   - role: `admin`
   - status: `active`
   - password_hash: (see below)

**Password hash ke liye:**
Backend terminal mein:
```
node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('admin123', 10).then(hash => console.log(hash))"
```

Output ko copy karke password_hash field mein paste karo.

## 🎉 Bas Itna Hi!

**`ERP_KHOLO.bat`** double-click karo aur ERP kholo! 🚀

---

**Koi problem?** `SIMPLE_SETUP.md` file padho.


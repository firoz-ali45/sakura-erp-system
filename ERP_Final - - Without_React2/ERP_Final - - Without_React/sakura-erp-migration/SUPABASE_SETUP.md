# Supabase Setup - Online Database (Easiest Way!)

## Kya Hai Supabase?

Supabase = Free PostgreSQL database online (cloud mein)
- ✅ Installation nahi chahiye
- ✅ pgAdmin ki zarurat nahi
- ✅ Free tier available
- ✅ Easy setup

## Step-by-Step Setup

### Step 1: Supabase Account

1. Browser kholo
2. https://supabase.com par jao
3. **"Start your project"** button click karo
4. **GitHub se sign up** karo (free, easy)

### Step 2: New Project Create

1. **"New Project"** click karo
2. **Project details:**
   - Name: `sakura-erp`
   - Database Password: (apna password set karo - yaad rakhna!)
   - Region: `Southeast Asia (Mumbai)` ya closest
3. **"Create new project"** click karo
4. 2-3 minutes wait karo (database setup ho raha hai)

### Step 3: Database URL Copy Karo

1. Project open hone ke baad
2. **Left sidebar** → **Settings** (gear icon)
3. **"Database"** click karo
4. **"Connection string"** section mein
5. **"URI"** tab select karo
6. **Connection string copy karo:**
   ```
   postgresql://postgres:[Firoz112233@@4]@db.xxxxx.supabase.co:5432/postgres
   ```

### Step 4: Backend .env File Update

1. **Backend folder** mein `.env` file kholo
2. **DATABASE_URL** update karo:
   ```env
   DATABASE_URL="postgresql://postgres:[Firoz112233@@4]@db.xxxxx.supabase.co:5432/postgres"
   ```
   (Copy kiya hua connection string paste karo)

3. **Save** karo

### Step 5: Prisma Migrations Run

**PowerShell terminal mein:**

```powershell
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration\backend"

# Dependencies install (agar nahi kiye)
npm install

# Prisma client generate
npm run prisma:generate

# Database migrations run (tables create honge)
npm run prisma:migrate
```

### Step 6: Verify

**Supabase Dashboard mein:**
1. **Left sidebar** → **"Table Editor"**
2. Tables dikhni chahiye (users, inventory_items, etc.)

**Bas! Database ready! ✅**

## Admin User Create Karein

### Option 1: Supabase SQL Editor Se

1. Supabase Dashboard → **SQL Editor**
2. Ye query run karo:

```sql
-- Password hash generate karo (bcrypt)
-- Pehle backend terminal mein:
-- node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('admin123', 10).then(hash => console.log(hash))"

-- Phir Supabase SQL Editor mein:
INSERT INTO users (
  email,
  name,
  password_hash,
  role,
  status,
  permissions
) VALUES (
  'admin@sakura.com',
  'Admin User',
  '$2a$10$YOUR_HASH_HERE',  -- Backend se generated hash
  'admin',
  'active',
  '{"accountsPayable": true, "forecasting": true, "warehouse": true, "userManagement": true, "reports": true, "settings": true}'::jsonb
);
```

### Option 2: Prisma Studio Se

```powershell
cd backend
npm run prisma:studio
```

Browser mein Prisma Studio khulega, wahan se user create karo.

## Benefits

✅ **No pgAdmin needed**
✅ **No local PostgreSQL needed**
✅ **Works from anywhere**
✅ **Free tier sufficient**
✅ **Easy backup/restore**
✅ **Better than local setup**

---

**Recommendation: Supabase use karo - sabse easy aur reliable!**


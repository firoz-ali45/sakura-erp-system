# Next Steps - pgAdmin Se Database Create Karein

## Step 1: PostgreSQL Server Connect Karein

pgAdmin welcome screen mein:

1. **Left side** par "Servers" section dikhega
2. **"Servers"** par **right-click** karo
3. **"Create" → "Server"** click karo

### Server Connection Details:

**General Tab:**
- **Name**: `Local PostgreSQL` (ya kuch bhi naam)

**Connection Tab:**
- **Host name/address**: `localhost`
- **Port**: `5432`
- **Maintenance database**: `postgres`
- **Username**: `postgres`
- **Password**: (apna PostgreSQL password - jo install ke time set kiya tha)

4. **"Save"** button click karo

5. Server connect ho jayega! ✅

## Step 2: Database Create Karein

1. **Left side** par "Servers" → "Local PostgreSQL" expand karo
2. **"Databases"** par **right-click** karo
3. **"Create" → "Database"** click karo

### Database Details:

**General Tab:**
- **Database**: `sakura_erp`
- **Owner**: `postgres` (default)
- **Comment**: (optional - "Sakura ERP Database")

4. **"Save"** button click karo

**Bas! Database ready! ✅**

## Step 3: Backend Setup

**PowerShell terminal kholo aur ye commands run karo:**

```powershell
# Correct path par jao
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration\backend"

# Dependencies install karo (pehli baar)
npm install

# Prisma client generate karo
npm run prisma:generate

# Database migrations run karo (tables create honge)
npm run prisma:migrate
```

## Step 4: Verify Database

pgAdmin mein:
1. **"sakura_erp"** database expand karo
2. **"Schemas" → "public" → "Tables"** expand karo
3. Tables dikhni chahiye:
   - users
   - inventory_items
   - inventory_categories
   - purchase_orders
   - etc.

**Agar tables dikh rahe hain, to database ready hai! ✅**

## Step 5: Admin User Create Karein

**Option 1: Prisma Studio Se (Easiest)**

```powershell
cd backend
npm run prisma:studio
```

Browser mein Prisma Studio khulega:
1. **"User"** model click karo
2. **"Add record"** button click karo
3. Ye fields fill karo:
   - email: `admin@sakura.com`
   - name: `Admin User`
   - role: `admin`
   - status: `active`
   - password_hash: (see below)

**Password hash generate karo:**
```powershell
node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('admin123', 10).then(hash => console.log(hash))"
```

Output ko copy karke password_hash field mein paste karo.

**Option 2: pgAdmin SQL Editor Se**

1. pgAdmin mein **"sakura_erp"** database select karo
2. **Tools → Query Tool** click karo
3. Ye query paste karo (pehle password hash generate karo):

```sql
-- Password hash generate karo (backend terminal mein):
-- node -e "const bcrypt = require('bcryptjs'); bcrypt.hash('admin123', 10).then(hash => console.log(hash))"

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
  '$2a$10$YOUR_HASH_HERE',  -- Backend se generated hash paste karo
  'admin',
  'active',
  '{"accountsPayable": true, "forecasting": true, "warehouse": true, "userManagement": true, "reports": true, "settings": true}'::jsonb
);
```

4. **Execute** button (F5) press karo

## Step 6: ERP Start Karein

**`ERP_KHOLO.bat`** file double-click karo!

Ya manually:

**Terminal 1 - Backend:**
```powershell
cd backend
npm run dev
```

**Terminal 2 - Frontend:**
```powershell
cd frontend
npm run dev
```

**Browser mein:**
- http://localhost:5173

**Login:**
- Email: `admin@sakura.com`
- Password: `admin123`

---

**Bas! ERP ready hai! 🎉**


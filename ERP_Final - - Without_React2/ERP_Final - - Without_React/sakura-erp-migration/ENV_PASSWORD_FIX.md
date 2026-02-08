# .env File Password Update

## Problem
Database authentication failed - password galat hai.

## Solution

### Step 1: .env File Kholo

**Backend folder** mein `.env` file kholo:
```
sakura-erp-migration\backend\.env
```

### Step 2: Password Update Karo

Current line:
```
DATABASE_URL="postgresql://postgres:password@localhost:5432/sakura_erp"
```

**`password` ko apne actual PostgreSQL password se replace karo:**

Example:
```
DATABASE_URL="postgresql://postgres:MY_ACTUAL_PASSWORD@localhost:5432/sakura_erp"
```

### Step 3: Save Karo

File save karo.

### Step 4: Migrations Phir Se Run Karo

```powershell
cd backend
npm run prisma:migrate
```

---

**Note:** Agar password yaad nahi hai:
1. pgAdmin kholo
2. Server connection check karo (wahan password dikhega)
3. Ya PostgreSQL reinstall karo with new password


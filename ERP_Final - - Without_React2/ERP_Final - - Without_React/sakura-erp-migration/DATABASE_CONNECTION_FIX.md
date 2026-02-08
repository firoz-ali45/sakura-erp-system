# Database Connection Fix

## Problem
Database connection timeout - PostgreSQL server reach nahi ho raha.

## Solutions

### Step 1: PostgreSQL Service Check Karein

**PowerShell mein:**
```powershell
Get-Service -Name postgresql*
```

Agar service **Stopped** hai, to start karo:
```powershell
Start-Service postgresql-x64-18
```
(18 ki jagah apna version ho sakta hai)

### Step 2: Database Create Karein (pgAdmin Se)

**pgAdmin kholo aur:**

1. **Server connect karo** (agar nahi kiya):
   - "Servers" par right-click
   - "Create" → "Server"
   - Connection details fill karo
   - Save

2. **Database create karo:**
   - "Servers" → "Local PostgreSQL" expand
   - "Databases" par right-click
   - "Create" → "Database"
   - Name: `sakura_erp`
   - Save

### Step 3: Connection Test Karein

**pgAdmin Query Tool mein:**
```sql
SELECT 1;
```

Agar query run ho, to database ready hai!

### Step 4: Migrations Phir Se Run Karein

```powershell
cd backend
npm run prisma:migrate
```

---

## Quick Checklist

- [ ] PostgreSQL service running hai?
- [ ] Database `sakura_erp` create ho gaya?
- [ ] .env file mein correct password hai?
- [ ] pgAdmin se database connect ho raha hai?

---

**Agar abhi bhi problem hai, to PostgreSQL service start karo aur database create karo!**


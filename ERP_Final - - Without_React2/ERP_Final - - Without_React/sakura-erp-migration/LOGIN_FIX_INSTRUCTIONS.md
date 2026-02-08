# Login Fix Instructions

## Problem
"Login failed" error appears when trying to login.

## Solution

### Step 1: Start Backend Server

The backend server must be running on port 3000 for login to work.

**Option A: Using Batch File (Easiest)**
1. Double-click `START_BACKEND.bat` in the `sakura-erp-migration` folder
2. Wait for "🚀 Sakura ERP Backend running on http://localhost:3000" message

**Option B: Manual Start**
1. Open PowerShell/Terminal
2. Navigate to backend folder:
   ```powershell
   cd sakura-erp-migration\backend
   ```
3. Start server:
   ```powershell
   npm run dev
   ```
4. Wait for "🚀 Sakura ERP Backend running on http://localhost:3000" message

### Step 2: Verify Backend is Running

Open browser and go to: `http://localhost:3000/api/health`

You should see:
```json
{"status":"ok","timestamp":"..."}
```

### Step 3: Create Admin User (If Not Exists)

If admin user doesn't exist, run:

```powershell
cd sakura-erp-migration\backend
npm run seed:admin
```

**Default Admin Credentials:**
- Email: `sakurapersonal071@gmail.com`
- Password: `Firoz112233@@`

### Step 4: Try Login Again

1. Make sure backend is running (Step 1)
2. Go to `http://localhost:5173/login`
3. Enter credentials:
   - Email: `sakurapersonal071@gmail.com`
   - Password: `Firoz112233@@`
4. Click "Sign In"

## Troubleshooting

### Error: "Backend server not running"
- **Solution**: Start backend server (Step 1)

### Error: "Invalid email or password"
- **Solution**: 
  1. Run `npm run seed:admin` to create/update admin user
  2. Make sure you're using correct password: `Firoz112233@@`

### Error: "Account is not active"
- **Solution**: Admin user should be active. Run seed script again:
  ```powershell
  npm run seed:admin
  ```

### Database Connection Error
- **Solution**: 
  1. Check PostgreSQL is running
  2. Verify `.env` file has correct `DATABASE_URL`
  3. Run `npm run prisma:generate` in backend folder

## Quick Start (All-in-One)

Use `ERP_KHOLO.bat` - it will:
1. Install dependencies
2. Start backend
3. Start frontend
4. Open browser


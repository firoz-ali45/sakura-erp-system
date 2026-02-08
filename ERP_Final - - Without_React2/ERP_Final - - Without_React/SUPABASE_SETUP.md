# 🔥 Supabase Setup Guide for Sakura ERP

## ✅ **STEP 1: Get Your Supabase Credentials**

1. Go to https://supabase.com/dashboard
2. Login to your account
3. Select your project (or create a new one)
4. Go to **Settings** → **API**
5. Copy these values:
   - **Project URL** (e.g., `https://abcdefghijklmnop.supabase.co`)
   - **anon public** key (starts with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)

## ✅ **STEP 2: Update index.html**

Open `index.html` and find these lines (around line 1454):

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

Replace with your actual values:

```javascript
const SUPABASE_URL = 'https://your-project-id.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

## ✅ **STEP 3: Create Database Schema**

1. Go to Supabase Dashboard → **SQL Editor**
2. Click **New Query**
3. Copy and paste this SQL:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users Table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT,
  phone TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user', 'manager', 'viewer')),
  status TEXT DEFAULT 'inactive' CHECK (status IN ('active', 'inactive', 'suspended')),
  permissions JSONB DEFAULT '{
    "accountsPayable": false,
    "forecasting": false,
    "warehouse": false,
    "userManagement": false,
    "reports": false,
    "settings": false
  }'::jsonb,
  notes TEXT,
  profile_photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE,
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMP WITH TIME ZONE
);

-- Create Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own data
CREATE POLICY "Users can view own data"
  ON users FOR SELECT
  USING (auth.uid()::text = id::text);

-- Policy: Admins can do everything
CREATE POLICY "Admins full access"
  ON users FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id::text = auth.uid()::text
      AND role = 'admin'
      AND status = 'active'
    )
  );

-- Function to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

4. Click **Run** (or press Ctrl+Enter)

## ✅ **STEP 4: Create Storage Bucket for Profile Photos**

1. Go to **Storage** in Supabase Dashboard
2. Click **New bucket**
3. Name: `profile-photos`
4. Set to **Public**
5. Click **Create bucket**

## ✅ **STEP 5: Test the Integration**

1. Open `index.html` in browser
2. Open Browser Console (F12)
3. You should see: `✅ Supabase initialized successfully`
4. Try signing up a new user
5. Check Supabase Dashboard → **Table Editor** → **users** table

## 🔧 **TROUBLESHOOTING**

### Issue: "Supabase not configured"
- Check if you've updated SUPABASE_URL and SUPABASE_ANON_KEY
- Make sure there are no extra spaces or quotes

### Issue: "Error fetching users"
- Check if you've run the SQL schema
- Check if RLS policies are correct
- Check browser console for detailed error

### Issue: "Permission denied"
- Check Row Level Security policies
- Make sure admin user exists and is active

## 📝 **NEXT STEPS**

After setup:
1. ✅ Test user signup
2. ✅ Test user login
3. ✅ Test admin user management
4. ✅ Test profile photo upload

## 🎯 **MIGRATION FROM LOCALSTORAGE**

The system will:
- ✅ Use Supabase if configured
- ✅ Fallback to localStorage if Supabase fails
- ✅ Gradually migrate data to Supabase

**To migrate existing users:**
1. Export from localStorage
2. Import to Supabase using SQL or Dashboard

---

**Need Help?** Check the console logs for detailed error messages! 🚀


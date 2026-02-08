# 🔥 Supabase Integration Guide for Sakura ERP

## 📋 **STEP 1: Get Your Supabase Credentials**

1. Go to https://supabase.com/dashboard
2. Select your project (or create new one)
3. Go to **Settings** → **API**
4. Copy these:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)

## 📋 **STEP 2: Database Schema Setup**

Run this SQL in Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users Table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
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

-- Create Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own data
CREATE POLICY "Users can view own data"
  ON users FOR SELECT
  USING (auth.uid()::text = id::text);

-- Policy: Admins can view all users
CREATE POLICY "Admins can view all users"
  ON users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id::text = auth.uid()::text
      AND role = 'admin'
      AND status = 'active'
    )
  );

-- Policy: Admins can insert users
CREATE POLICY "Admins can insert users"
  ON users FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id::text = auth.uid()::text
      AND role = 'admin'
      AND status = 'active'
    )
  );

-- Policy: Admins can update users
CREATE POLICY "Admins can update users"
  ON users FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id::text = auth.uid()::text
      AND role = 'admin'
      AND status = 'active'
    )
  );

-- Policy: Admins can delete users
CREATE POLICY "Admins can delete users"
  ON users FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id::text = auth.uid()::text
      AND role = 'admin'
      AND status = 'active'
    )
  );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert Default Admin User (Change password after first login!)
-- Password: Firoz112233@@ (will be hashed)
INSERT INTO users (
  email,
  name,
  password_hash,
  role,
  status,
  permissions,
  notes
) VALUES (
  'sakurapersonal071@gmail.com',
  'Firoz Admin',
  '$2a$10$YourHashedPasswordHere', -- Replace with actual bcrypt hash
  'admin',
  'active',
  '{
    "accountsPayable": true,
    "forecasting": true,
    "warehouse": true,
    "userManagement": true,
    "reports": true,
    "settings": true
  }'::jsonb,
  'Main Administrator - Default Admin Account'
) ON CONFLICT (email) DO NOTHING;
```

## 📋 **STEP 3: Storage Setup for Profile Photos**

1. Go to **Storage** in Supabase Dashboard
2. Create a new bucket named `profile-photos`
3. Set it to **Public**
4. Add policy:
   - **Policy Name:** "Public Access"
   - **Allowed Operations:** SELECT, INSERT, UPDATE
   - **Policy Definition:** `true` (for now, can restrict later)

## 📋 **STEP 4: Environment Variables**

Create a file `.env` (or add to your HTML):

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL'
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'
```

## 📋 **STEP 5: Integration Steps**

1. Add Supabase SDK to HTML
2. Initialize Supabase client
3. Replace localStorage functions with Supabase
4. Update authentication
5. Update user management CRUD

---

## 🔐 **IMPORTANT: Password Hashing**

Since Supabase Auth uses its own system, we have two options:

### **Option A: Use Supabase Auth (Recommended)**
- Use Supabase's built-in authentication
- Automatic password hashing
- Email verification
- Password reset

### **Option B: Custom Auth with bcrypt**
- Hash passwords on client (not recommended)
- Or use Supabase Edge Functions for hashing

**I recommend Option A - using Supabase Auth!**

---

## 📝 **Next Steps:**

1. Share your Supabase Project URL and Anon Key (or I can guide you to set it up)
2. I'll integrate it into your index.html
3. We'll migrate from localStorage to Supabase
4. Test the complete system

Ready to proceed? 🚀


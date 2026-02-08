# 🚀 Next Steps - Supabase Integration

## ✅ **STEP 1: Credentials Added**
Your Supabase credentials have been added to `index.html`!

---

## 📋 **STEP 2: Create Database Schema**

### **Option A: Using Supabase Dashboard (Recommended)**

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query** button
4. Open the file `DATABASE_SCHEMA.sql` (I just created it for you)
5. Copy ALL the SQL code from that file
6. Paste it into the SQL Editor
7. Click **Run** (or press Ctrl+Enter)
8. Wait for success message: ✅ "Success. No rows returned"

### **Option B: Direct SQL**

Just copy this and run in SQL Editor:

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

-- Policies (Simplified for now - we'll use service role for admin operations)
CREATE POLICY "Enable read access for all users" ON users FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for authenticated users" ON users FOR UPDATE USING (true);
CREATE POLICY "Enable delete for authenticated users" ON users FOR DELETE USING (true);

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

---

## 📋 **STEP 3: Create Storage Bucket for Profile Photos**

1. Go to **Storage** in Supabase Dashboard
2. Click **New bucket**
3. Name: `profile-photos`
4. Set to **Public** (tick the checkbox)
5. Click **Create bucket**

---

## 📋 **STEP 4: Test the Integration**

1. Open `index.html` in your browser
2. Press **F12** to open Developer Console
3. Look for this message:
   - ✅ `✅ Supabase initialized successfully` = **SUCCESS!**
   - ❌ `⚠️ Supabase not configured` = Check credentials

---

## 📋 **STEP 5: Verify Database**

1. Go to Supabase Dashboard → **Table Editor**
2. Click on **users** table
3. You should see the default admin user:
   - Email: `sakurapersonal071@gmail.com`
   - Name: `Firoz Admin`
   - Role: `admin`
   - Status: `active`

---

## 🔧 **IMPORTANT: Row Level Security (RLS)**

For now, I've set simple policies that allow all operations. 

**For Production:**
- We'll need to implement proper RLS policies
- Or use Supabase Auth for authentication
- Or create Edge Functions for admin operations

**Current Setup:**
- ✅ Table created
- ✅ Indexes created
- ✅ Basic RLS enabled
- ⚠️ Policies are permissive (for testing)

---

## 🎯 **What's Next?**

After database setup:

1. ✅ **Test User Signup** - Try creating a new user
2. ✅ **Test User Login** - Try logging in
3. ✅ **Test User Management** - Admin can manage users
4. ✅ **Test Profile Photos** - Upload profile pictures

---

## 🆘 **Troubleshooting**

### Issue: "Table already exists"
- ✅ That's fine! The schema uses `IF NOT EXISTS`
- Just continue to next step

### Issue: "Permission denied"
- Check RLS policies
- For testing, policies are set to allow all
- For production, we'll tighten security

### Issue: "Supabase not initialized"
- Check browser console
- Verify credentials in index.html
- Make sure no typos in URL or key

---

## ✅ **Checklist**

- [x] Credentials added to index.html
- [ ] Database schema created (SQL Editor)
- [ ] Storage bucket created (profile-photos)
- [ ] Test in browser (F12 console)
- [ ] Verify users table exists

---

**Ready?** Run the SQL schema and let me know when done! 🚀


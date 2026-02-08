# 🔐 Quick Admin Login Fix

## ✅ **Fix Applied:**

1. **Admin OTP Bypass** - Admin users can now login without email verification (OTP)
2. **Auto Email Verification** - Admin email automatically verified on login
3. **Fallback Password** - Still works: `Sakura@@` (without email)

---

## 🚀 **Login Methods:**

### **Method 1: Admin Email + Password**
1. Enter admin email: `sakurapersonal071@gmail.com` (or your admin email)
2. Enter password
3. Click "Access ERP System"
4. **Admin can now login directly** (OTP bypassed)

### **Method 2: Fallback Password (Quick Access)**
1. **Leave email field empty**
2. Enter password: `Sakura@@`
3. Click "Access ERP System"
4. Direct access (no email verification needed)

---

## 🔍 **If Still Not Working:**

### **Check Browser Console:**
1. Press `F12` to open Developer Tools
2. Go to "Console" tab
3. Try login again
4. Check for error messages

### **Common Issues:**

1. **"User not found"**
   - Admin user might not exist in Supabase
   - Solution: Create admin user via Sign Up

2. **"Account pending approval"**
   - User status is not 'active'
   - Solution: Update user status to 'active' in Supabase

3. **"Email verification required"**
   - Should be bypassed for admin now
   - If still showing, check user role is 'admin' or 'administrator'

4. **Password mismatch**
   - Check password in Supabase matches exactly
   - No extra spaces

---

## 🛠️ **Manual Fix (Supabase Dashboard):**

1. Go to Supabase Dashboard
2. Open `users` table
3. Find admin user
4. Update:
   - `status` = `active`
   - `email_verified` = `true`
   - `role` = `admin` or `administrator`
5. Save and try login again

---

## ✅ **Quick Test:**

**Try this:**
1. Email: (leave empty)
2. Password: `Sakura@@`
3. Click login

**Should work immediately!** ✅

---

**If still having issues, check browser console for specific error messages.**

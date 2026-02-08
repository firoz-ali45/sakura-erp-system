# 📧 SendGrid Email Setup Instructions

## ✅ **Step 1: Run SQL Script in Supabase**

1. Supabase Dashboard → **SQL Editor** → **New Query**
2. Copy and paste the contents of `ADD_EMAIL_VERIFIED_COLUMN.sql`
3. Click **Run** to execute
4. Verify: Check that `email_verified` column exists in `users` table

---

## ✅ **Step 2: Verify Sender Email in SendGrid**

### **Important:** SendGrid requires sender email verification before sending emails.

1. Go to **SendGrid Dashboard**: https://app.sendgrid.com/
2. Navigate to: **Settings** → **Sender Authentication** → **Verify a Single Sender**
3. Click **Create New Sender**
4. Fill in the form:
   - **From Email**: `sakurapersonal071@gmail.com` (or your verified email)
   - **From Name**: `Sakura ERP`
   - **Reply To**: `sakurapersonal071@gmail.com`
   - **Company Address**: Your company address
   - **City**: Your city
   - **State**: Your state
   - **Country**: Your country
   - **Zip Code**: Your zip code
5. Click **Create**
6. **Check your email inbox** for verification email from SendGrid
7. Click the verification link in the email
8. **Sender is now verified!** ✅

---

## ✅ **Step 3: Update Sender Email in Code (if needed)**

If you want to use a different sender email:

1. Open `index.html`
2. Find this line (around line 3008):
   ```javascript
   const SENDGRID_FROM_EMAIL = 'sakurapersonal071@gmail.com';
   ```
3. Update with your verified sender email
4. Save the file

---

## ✅ **Step 4: Test Email Sending**

1. **Refresh the browser** (Ctrl+F5)
2. **Login** with an admin account
3. **Create a new user** or **approve an existing user**
4. Check console (F12) for email sending logs:
   - `✅ Email sent successfully via SendGrid` = Success!
   - `❌ SendGrid API error` = Check API key and sender verification
5. **Check user's email inbox** for OTP email

---

## 🔧 **Troubleshooting**

### **Error: "The from email does not match a verified Sender Identity"**
- **Solution**: Verify sender email in SendGrid (Step 2 above)

### **Error: "401 Unauthorized"**
- **Solution**: Check that API key is correct: `J-tx9kyPSHeAwxl6GNkDfw`

### **Error: "email_verified column not found"**
- **Solution**: Run `ADD_EMAIL_VERIFIED_COLUMN.sql` in Supabase (Step 1 above)

### **OTP not received in email**
- Check **Spam folder**
- Verify sender email is verified in SendGrid
- Check console (F12) for SendGrid API errors
- Verify API key has "Mail Send" permissions

---

## 📝 **Current Configuration**

- **API Key**: `J-tx9kyPSHeAwxl6GNkDfw` ✅
- **Sender Email**: `sakurapersonal071@gmail.com` (needs verification)
- **Email Service**: SendGrid ✅
- **Status**: Ready to use after sender verification

---

## 🎯 **Next Steps After Setup**

1. ✅ Run SQL script to add `email_verified` column
2. ✅ Verify sender email in SendGrid
3. ✅ Test email sending
4. ✅ User receives OTP in email
5. ✅ User enters OTP → Email verified → Login successful!

---

**Note**: SendGrid free tier allows 100 emails per day. For production, consider upgrading to a paid plan.


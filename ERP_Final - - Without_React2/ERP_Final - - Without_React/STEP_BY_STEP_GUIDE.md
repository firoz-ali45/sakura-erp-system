# 📧 Email Verification System - Step by Step Guide

## ✅ Step 1: Supabase me SQL Script Run Karna

### Kya Karna Hai:
OTP columns (`otp_code` aur `otp_expiry`) ko `users` table me add karna.

### Kaise Karein:

1. **Supabase Dashboard Kholo:**
   - Browser me [https://supabase.com](https://supabase.com) par jao
   - Apna project select karo
   - Login karo

2. **SQL Editor Kholo:**
   - Left sidebar me **"SQL Editor"** par click karo
   - Ya direct URL: `https://supabase.com/dashboard/project/[YOUR_PROJECT_ID]/sql`

3. **SQL Script Copy Karo:**
   - Project folder me `ADD_OTP_COLUMNS.sql` file kholo
   - Saara code copy karo (Ctrl+A, Ctrl+C)

4. **SQL Editor me Paste Karo:**
   - Supabase SQL Editor me paste karo (Ctrl+V)
   - Ya manually type karo:

```sql
-- Add OTP code column (stores the 6-digit OTP)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS otp_code TEXT;

-- Add OTP expiry column (stores when the OTP expires)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS otp_expiry TIMESTAMP WITH TIME ZONE;

-- Add comment to columns
COMMENT ON COLUMN users.otp_code IS 'One-Time Password for email verification (6 digits)';
COMMENT ON COLUMN users.otp_expiry IS 'Expiry timestamp for the OTP (valid for 10 minutes)';

-- Create index on otp_code for faster lookups (optional)
CREATE INDEX IF NOT EXISTS idx_users_otp_code ON users(otp_code) WHERE otp_code IS NOT NULL;
```

5. **Run Karo:**
   - Bottom right me **"Run"** button par click karo
   - Ya `Ctrl+Enter` press karo

6. **Success Check:**
   - Agar success message aaye: "Success. No rows returned" ya similar
   - Agar error aaye to check karo ki `users` table exist karta hai

7. **Verify Karo:**
   - Left sidebar me **"Table Editor"** par jao
   - `users` table select karo
   - Columns check karo - `otp_code` aur `otp_expiry` dikhne chahiye

---

## 📧 Step 2: Email Service Integrate Karna (Production)

### Abhi Kya Ho Raha Hai:
- Abhi emails console me log ho rahe hain (development mode)
- Production me actual emails send karne ke liye email service chahiye

### Options:

### Option 1: Supabase Email Service (Easiest - Recommended)

**Kya Hai:**
- Supabase ka built-in email service
- Setup easy hai
- Free tier available

**Kaise Setup Karein:**

1. **Supabase Dashboard:**
   - Project settings me jao
   - **"Auth"** section me jao
   - **"Email Templates"** section check karo

2. **SMTP Settings:**
   - **"Settings"** → **"Auth"** → **"SMTP Settings"**
   - Ya **"Project Settings"** → **"Auth"** → **"SMTP"**

3. **SMTP Provider Choose Karo:**
   - **SendGrid** (Recommended - Free tier: 100 emails/day)
   - **Mailgun** (Free tier: 5,000 emails/month)
   - **AWS SES** (Pay as you go)
   - **Gmail SMTP** (Free but limited)

4. **SendGrid Setup (Example):**
   - [SendGrid.com](https://sendgrid.com) par account banao
   - **Settings** → **API Keys** → **Create API Key**
   - API Key copy karo
   - Supabase me paste karo:
     - **SMTP Host:** `smtp.sendgrid.net`
     - **SMTP Port:** `587`
     - **SMTP User:** `apikey`
     - **SMTP Password:** (Your SendGrid API Key)
     - **Sender Email:** (Your verified email)

5. **Code Me Update:**
   - `sendProfessionalEmail()` function me actual email sending code add karo
   - Supabase Edge Function use karo ya direct SMTP

---

### Option 2: SendGrid API (Direct Integration)

**Kya Hai:**
- SendGrid ka direct API integration
- More control
- Better for custom emails

**Kaise Setup Karein:**

1. **SendGrid Account:**
   - [SendGrid.com](https://sendgrid.com) par sign up karo
   - Free tier: 100 emails/day

2. **API Key Generate:**
   - Dashboard → **Settings** → **API Keys**
   - **Create API Key** button
   - **Full Access** select karo
   - API Key copy karo (sirf ek baar dikhega!)

3. **Code Me Add Karo:**
   - `index.html` me `sendProfessionalEmail()` function me:

```javascript
// SendGrid API Integration
async function sendEmailViaSendGrid(to, subject, htmlContent) {
    const SENDGRID_API_KEY = 'YOUR_SENDGRID_API_KEY_HERE'; // Replace with your API key
    const SENDGRID_URL = 'https://api.sendgrid.com/v3/mail/send';
    
    const emailData = {
        personalizations: [{
            to: [{ email: to }],
            subject: subject
        }],
        from: { email: 'noreply@sakuraerp.com', name: 'Sakura ERP' }, // Your verified sender
        content: [{
            type: 'text/html',
            value: htmlContent
        }]
    };
    
    try {
        const response = await fetch(SENDGRID_URL, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${SENDGRID_API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(emailData)
        });
        
        if (response.ok) {
            console.log('✅ Email sent via SendGrid');
            return { success: true };
        } else {
            const error = await response.text();
            console.error('❌ SendGrid error:', error);
            return { success: false, error: error };
        }
    } catch (error) {
        console.error('❌ SendGrid API error:', error);
        return { success: false, error: error.message };
    }
}

// Update sendProfessionalEmail function
async function sendProfessionalEmail(userEmail, userName, emailType, additionalData = {}) {
    // ... existing code to generate emailBody ...
    
    // Send actual email via SendGrid
    const emailResult = await sendEmailViaSendGrid(userEmail, subject, emailBody);
    
    return emailResult;
}
```

**Security Note:**
- API key ko directly code me mat rakho (security risk)
- Environment variables use karo ya Supabase Edge Function me rakho

---

### Option 3: AWS SES (Amazon Simple Email Service)

**Kya Hai:**
- Amazon ka email service
- Very reliable
- Pay as you go (cheap)

**Kaise Setup Karein:**

1. **AWS Account:**
   - [AWS Console](https://console.aws.amazon.com) par jao
   - **SES** service search karo

2. **Email Verification:**
   - **Verified identities** → **Create identity**
   - Apna email verify karo

3. **SMTP Credentials:**
   - **SMTP settings** → **Create SMTP credentials**
   - Username aur password generate karo

4. **Code Me Add:**
   - Similar to SendGrid, SMTP use karo

---

### Option 4: Nodemailer (Node.js Backend Required)

**Kya Hai:**
- Node.js library for sending emails
- Multiple providers support
- Backend server chahiye

**Kaise Setup Karein:**

1. **Backend Server Setup:**
   - Node.js server banao
   - Express.js use karo

2. **Install Nodemailer:**
```bash
npm install nodemailer
```

3. **Backend Code:**
```javascript
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    service: 'gmail', // or 'sendgrid', 'mailgun', etc.
    auth: {
        user: 'your-email@gmail.com',
        pass: 'your-app-password'
    }
});

app.post('/send-email', async (req, res) => {
    const { to, subject, html } = req.body;
    
    await transporter.sendMail({
        from: 'Sakura ERP <noreply@sakuraerp.com>',
        to: to,
        subject: subject,
        html: html
    });
    
    res.json({ success: true });
});
```

4. **Frontend Me Call:**
```javascript
await fetch('https://your-backend.com/send-email', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ to: userEmail, subject: subject, html: emailBody })
});
```

---

## 🎯 Recommended Approach (Easiest)

### For Quick Testing:
1. **Abhi ke liye:** Console me OTP dikh raha hai - yeh theek hai testing ke liye
2. **Production ke liye:** SendGrid use karo (free tier sufficient hai)

### Step-by-Step SendGrid Setup:

1. **SendGrid Account:**
   - [https://sendgrid.com/free/](https://sendgrid.com/free/) par sign up
   - Email verify karo

2. **API Key:**
   - Dashboard → Settings → API Keys → Create API Key
   - Copy karo

3. **Sender Verify:**
   - Settings → Sender Authentication
   - Single Sender Verification
   - Apna email verify karo

4. **Code Update:**
   - `index.html` me `sendProfessionalEmail()` function me SendGrid code add karo
   - API key ko environment variable me rakho (production me)

---

## ⚠️ Important Notes:

1. **API Keys Security:**
   - API keys ko directly code me mat commit karo
   - `.env` file use karo ya Supabase secrets

2. **Email Limits:**
   - Free tiers me daily/monthly limits hote hain
   - Production me paid plan consider karo

3. **Email Templates:**
   - Current HTML templates already professional hain
   - Customize kar sakte ho

4. **Testing:**
   - Pehle test emails bhejo
   - Spam folder check karo
   - Email deliverability test karo

---

## 🚀 Quick Start (Minimum Setup):

1. **SQL Script Run Karo** (Required)
2. **Abhi ke liye console me OTP check karo** (Testing)
3. **Production me SendGrid add karo** (When ready)

---

## 📞 Need Help?

Agar koi step unclear hai ya error aaye to:
1. Console me error check karo (F12)
2. Supabase logs check karo
3. SendGrid dashboard me delivery status check karo


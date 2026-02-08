# 📧 Supabase Edge Function Setup - Email Sending (No CORS Issues!)

## ✅ **Problem Solved:**
- ❌ Browser se directly SendGrid API call nahi ho sakti (CORS error)
- ✅ Supabase Edge Function server-side se email bhejega (No CORS!)

---

## 🚀 **STEP 1: Install Supabase CLI**

### **Windows:**
```powershell
# Option 1: Using Scoop
scoop install supabase

# Option 2: Using npm
npm install -g supabase
```

### **Mac/Linux:**
```bash
brew install supabase/tap/supabase
```

### **Verify Installation:**
```bash
supabase --version
```

---

## 🚀 **STEP 2: Login to Supabase**

```bash
supabase login
```

Browser me login page khulega, login karo.

---

## 🚀 **STEP 3: Link Your Project**

```bash
# Supabase Dashboard se project reference ID lein
supabase link --project-ref YOUR_PROJECT_REF_ID
```

**Project Ref ID kahan se milega:**
1. Supabase Dashboard → Settings → General
2. **Reference ID** copy karo (e.g., `kexwnurwavszvmlpifsf`)

---

## 🚀 **STEP 4: Create Edge Function**

```bash
# Function create karo
supabase functions new send-email
```

Ye command `supabase/functions/send-email/` folder create karega.

---

## 🚀 **STEP 5: Copy Function Code**

1. `supabase/functions/send-email/index.ts` file open karo
2. File me jo code hai, use replace karo with `SUPABASE_EDGE_FUNCTION_CODE.md` me diya hua code

Ya phir maine already `supabase/functions/send-email/index.ts` file create kar di hai - check karo.

---

## 🚀 **STEP 6: Set Environment Variables (Secrets)**

```bash
# SendGrid API Key set karo
supabase secrets set SENDGRID_API_KEY=J-tx9kyPSHeAwxl6GNkDfw

# Sender email set karo (optional, default already set)
supabase secrets set SENDGRID_FROM_EMAIL=sakurapersonal071@gmail.com
```

---

## 🚀 **STEP 7: Deploy Edge Function**

```bash
# Function deploy karo
supabase functions deploy send-email
```

**Output:**
```
Deploying send-email...
Function URL: https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-email
```

---

## 🚀 **STEP 8: Update Frontend Code**

`index.html` me `sendEmailViaService` function update karo:

```javascript
async function sendEmailViaService(toEmail, subject, htmlContent) {
    try {
        // Supabase Edge Function call (no CORS issues!)
        const supabaseUrl = SUPABASE_URL; // Your Supabase URL
        const supabaseAnonKey = SUPABASE_ANON_KEY; // Your Supabase anon key
        
        const response = await fetch(`${supabaseUrl}/functions/v1/send-email`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${supabaseAnonKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                toEmail: toEmail,
                subject: subject,
                htmlContent: htmlContent
            })
        });
        
        if (response.ok) {
            const result = await response.json();
            console.log('✅ Email sent successfully via Supabase Edge Function');
            return { success: true };
        } else {
            const error = await response.json();
            console.error('❌ Edge Function error:', error);
            return { success: false, error: error.error || 'Failed to send email' };
        }
    } catch (error) {
        console.error('❌ Error calling Edge Function:', error);
        return { success: false, error: error.message || 'Failed to send email' };
    }
}
```

---

## ✅ **STEP 9: Test Email Sending**

1. Browser refresh karo (Ctrl+F5)
2. Login karo
3. New user create karo ya approve karo
4. Console (F12) check karo:
   - `✅ Email sent successfully via Supabase Edge Function` = Success!
5. User ke email inbox me OTP check karo

---

## 🔧 **Troubleshooting**

### **Error: "Function not found"**
- **Solution**: Function deploy kiya hai? `supabase functions deploy send-email` run karo

### **Error: "Unauthorized"**
- **Solution**: Supabase anon key sahi hai? Check karo `index.html` me

### **Error: "SENDGRID_API_KEY not set"**
- **Solution**: `supabase secrets set SENDGRID_API_KEY=...` run karo

### **Email still not received**
- Check SendGrid Dashboard → Activity → Email Activity
- Verify sender email in SendGrid (Settings → Sender Authentication)

---

## 📝 **Quick Commands Reference**

```bash
# Login
supabase login

# Link project
supabase link --project-ref YOUR_PROJECT_REF_ID

# Create function
supabase functions new send-email

# Set secrets
supabase secrets set SENDGRID_API_KEY=J-tx9kyPSHeAwxl6GNkDfw

# Deploy function
supabase functions deploy send-email

# View logs
supabase functions logs send-email

# List functions
supabase functions list
```

---

## 🎯 **Benefits of Edge Function Approach:**

1. ✅ **No CORS Issues** - Server-side call, browser se directly nahi
2. ✅ **Secure** - API key server-side pe, frontend me expose nahi
3. ✅ **Supabase Native** - No third-party website needed
4. ✅ **Scalable** - Supabase handles scaling automatically
5. ✅ **Free Tier** - Supabase Edge Functions free tier me available

---

**Ready to deploy!** 🚀


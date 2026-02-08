# 📧 Step-by-Step Email Setup Guide (Hindi/English)

## 🎯 **Kya Karna Hai:**
Browser se directly SendGrid API call nahi ho sakti (CORS error). Isliye hum Supabase Edge Function use karenge jo server-side se email bhejega.

---

## ✅ **STEP 1: Node.js Install Karna (Agar Nahi Hai)**

### **Check Karein:**
1. **Windows PowerShell** open karo
2. Type karo: `node --version`
3. Agar version dikhe (jaise `v18.17.0`), to **STEP 2** par jao
4. Agar error aaye, to Node.js install karo

### **Node.js Install Kaise Karein:**
1. Browser me jao: https://nodejs.org/
2. **LTS version** download karo (recommended)
3. Installer run karo
4. **Next, Next, Next** click karte raho
5. Install complete hone ke baad **PowerShell restart** karo
6. Phir se check karo: `node --version`

---

## ✅ **STEP 2: Supabase CLI Install Karna**

### **PowerShell me ye command run karo:**
```powershell
npm install -g supabase
```

### **Kya Hoga:**
- Supabase CLI install ho jayega
- 1-2 minutes lag sakte hain
- Agar koi error aaye, to batao

### **Verify Karein:**
```powershell
supabase --version
```

**Expected Output:**
```
supabase 1.x.x
```

Agar version dikhe, to **STEP 3** par jao.

---

## ✅ **STEP 3: Supabase me Login Karna**

### **PowerShell me ye command run karo:**
```powershell
supabase login
```

### **Kya Hoga:**
1. Browser automatically khulega
2. Supabase login page dikhega
3. Apna **email** aur **password** daalo
4. **Sign In** click karo
5. Agar account nahi hai, to **Sign Up** karo (free hai)

### **Success Message:**
```
✅ Successfully logged in!
```

Agar ye message dikhe, to **STEP 4** par jao.

---

## ✅ **STEP 4: Apne Project se Link Karna**

### **PowerShell me ye command run karo:**
```powershell
supabase link --project-ref kexwnurwavszvmlpifsf
```

### **Kya Hoga:**
- Supabase aapke project se link ho jayega
- Database password puch sakta hai (agar set hai)

### **Success Message:**
```
✅ Linked to project kexwnurwavszvmlpifsf
```

Agar ye message dikhe, to **STEP 5** par jao.

---

## ✅ **STEP 5: SendGrid API Key Set Karna (Secret)**

### **PowerShell me ye command run karo:**
```powershell
supabase secrets set SENDGRID_API_KEY=J-tx9kyPSHeAwxl6GNkDfw
```

### **Kya Hoga:**
- SendGrid API key securely store ho jayega
- Ye secret hai, koi aur nahi dekh sakta

### **Success Message:**
```
✅ Secret SENDGRID_API_KEY set successfully
```

Agar ye message dikhe, to **STEP 6** par jao.

---

## ✅ **STEP 6: Edge Function Deploy Karna**

### **Pehle Check Karein:**
1. `supabase/functions/send-email/index.ts` file exist karti hai?
2. Agar nahi hai, to maine already create kar di hai - check karo

### **PowerShell me ye command run karo:**
```powershell
supabase functions deploy send-email
```

### **Kya Hoga:**
- Function deploy ho jayega
- 1-2 minutes lag sakte hain
- Function URL dikhega

### **Success Message:**
```
Deploying send-email...
Function URL: https://kexwnurwavszvmlpifsf.supabase.co/functions/v1/send-email
✅ Function deployed successfully!
```

Agar ye message dikhe, to **STEP 7** par jao.

---

## ✅ **STEP 7: Test Karna**

### **Browser me:**
1. **Refresh** karo (Ctrl+F5)
2. **Login** karo
3. **New user create** karo ya **approve** karo
4. **Console (F12)** open karo
5. Check karo:
   - `✅ Email sent successfully via Supabase Edge Function` = Success!

### **Email Check Karein:**
1. User ke **email inbox** me jao
2. **OTP email** check karo
3. Agar **spam** me hai, to wahan bhi check karo

---

## 🔧 **Agar Koi Error Aaye:**

### **Error 1: "npm: command not found"**
**Solution:** Node.js install karo (STEP 1)

### **Error 2: "supabase: command not found"**
**Solution:** `npm install -g supabase` run karo (STEP 2)

### **Error 3: "Not logged in"**
**Solution:** `supabase login` run karo (STEP 3)

### **Error 4: "Project not found"**
**Solution:** 
- Supabase Dashboard me jao
- Settings → General → Reference ID check karo
- Agar different hai, to woh use karo

### **Error 5: "Function not found"**
**Solution:** 
- `supabase/functions/send-email/index.ts` file check karo
- Agar nahi hai, to maine create kar di hai - verify karo

### **Error 6: "Email not received"**
**Solution:**
- SendGrid Dashboard me jao
- Settings → Sender Authentication → Verify a Single Sender
- Sender email verify karo

---

## 📝 **Quick Command Summary:**

```powershell
# 1. Install Supabase CLI
npm install -g supabase

# 2. Login
supabase login

# 3. Link Project
supabase link --project-ref kexwnurwavszvmlpifsf

# 4. Set API Key
supabase secrets set SENDGRID_API_KEY=J-tx9kyPSHeAwxl6GNkDfw

# 5. Deploy Function
supabase functions deploy send-email
```

---

## 🎯 **Video Tutorial (Agar Chahiye):**

Agar aapko visual guide chahiye, to:
1. YouTube me search karo: "Supabase Edge Functions deploy"
2. Ya phir main detailed screenshots bhi de sakta hoon

---

## ✅ **Success Checklist:**

- [ ] Node.js installed hai
- [ ] Supabase CLI installed hai
- [ ] Supabase me login ho gaya
- [ ] Project link ho gaya
- [ ] SendGrid API key set ho gaya
- [ ] Edge Function deploy ho gaya
- [ ] Test email send ho gaya
- [ ] OTP email inbox me aaya

---

**Agar koi step me problem aaye, to batao - main help karunga!** 🚀


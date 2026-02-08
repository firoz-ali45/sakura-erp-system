# 🔧 Password Dropdown Fix - SQLTools Connection

## ❌ **Problem:**
Password field mein dropdown hai aur direct password enter nahi kar sakte.

## ✅ **Solution:**

### **Step 1: Password Dropdown Se Option Select Karein**

1. **"Use password"** dropdown mein click karo
2. **"Save as plaintext in settings"** select karo
   - Ye option select karne se password field dikhega

### **Step 2: Password Enter Karein**

1. Dropdown select karne ke baad, **password input field** dikhega
2. **Apna Supabase database password** enter karo

### **Step 3: Server Address Fix Karein (Important!)**

**Current (Galat):**
```
Server Address: localhost
```

**Correct (Supabase):**
```
Server Address: db.kexwnurwavszvmlpifsf.supabase.co
```

**Fix:**
1. **"Server Address"** field mein `localhost` ko delete karo
2. **Ye address enter karo:** `db.kexwnurwavszvmlpifsf.supabase.co`

---

## 📋 **Complete Connection Settings:**

```
Connection name: Supabase ERP
Connection group: (optional, khali chhod sakte ho)
Connect using: Server and Port
Server Address: db.kexwnurwavszvmlpifsf.supabase.co  ← IMPORTANT!
Port: 5432
Database: postgres
Username: postgres
Use password: Save as plaintext in settings  ← Dropdown se ye select karo
Password: [YOUR_SUPABASE_PASSWORD]  ← Phir yahan password enter karo
```

---

## 🔑 **Password Kahan Se Milega?**

### **Supabase Dashboard Se:**

1. Browser mein jao: https://supabase.com/dashboard/project/kexwnurwavszvmlpifsf
2. **Settings** (⚙️) → **Database**
3. **Connection string** section
4. **URI** tab select karo
5. Connection string dikhega:
   ```
   postgresql://postgres:[PASSWORD]@db.kexwnurwavszvmlpifsf.supabase.co:5432/postgres
   ```
6. `[PASSWORD]` wala part copy karo (brackets ke bina)

**Ya phir:**
- Project create karte waqt jo password set kiya, wahi use karo

---

## ✅ **Step-by-Step Fix:**

1. ✅ **Server Address** field mein: `db.kexwnurwavszvmlpifsf.supabase.co` enter karo
2. ✅ **Use password** dropdown se: **"Save as plaintext in settings"** select karo
3. ✅ **Password field** mein: Apna Supabase database password enter karo
4. ✅ **"Test Connection"** click karo
5. ✅ Success ho to **"Save"** click karo

---

## 🎯 **Quick Checklist:**

- [ ] Server Address: `db.kexwnurwavszvmlpifsf.supabase.co` (not localhost)
- [ ] Port: `5432`
- [ ] Database: `postgres`
- [ ] Username: `postgres`
- [ ] Use password: **"Save as plaintext in settings"** (dropdown se)
- [ ] Password: [Your actual Supabase password]

---

## 🆘 **Agar Password Field Nahi Dikhe:**

1. **"Use password"** dropdown se **"Ask on connect"** select karo
2. Ya phir **"Save as plaintext in settings"** try karo
3. Agar phir bhi nahi dikhe, to connection save karo
4. Connection use karte waqt password prompt aayega

---

**Ab Server Address fix karo aur password dropdown se "Save as plaintext in settings" select karo! 🚀**

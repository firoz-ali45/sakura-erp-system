# 🚀 Simple Setup Guide - Email Sending Fix

## 🎯 **Problem:**
OTP email inbox me nahi aa raha kyunki browser se directly SendGrid API call nahi ho sakti (CORS error).

## ✅ **Solution:**
Supabase Edge Function use karenge jo server-side se email bhejega.

---

## 📋 **5 Simple Steps:**

### **1️⃣ PowerShell Open Karo**
- Windows key + X press karo
- **Windows PowerShell** select karo

### **2️⃣ Supabase CLI Install Karo**
PowerShell me type karo:
```
npm install -g supabase
```
Enter press karo. 1-2 minutes lag sakte hain.

### **3️⃣ Login Karo**
PowerShell me type karo:
```
supabase login
```
Enter press karo. Browser khulega, login karo.

### **4️⃣ Project Link Karo**
PowerShell me type karo:
```
supabase link --project-ref kexwnurwavszvmlpifsf
```
Enter press karo.

### **5️⃣ API Key Set Karo aur Function Deploy Karo**
PowerShell me ye 2 commands run karo (ek ek karke):
```
supabase secrets set SENDGRID_API_KEY=J-tx9kyPSHeAwxl6GNkDfw
```
Enter press karo. Phir:
```
supabase functions deploy send-email
```
Enter press karo. 1-2 minutes lag sakte hain.

---

## ✅ **Test Karein:**

1. Browser refresh karo (Ctrl+F5)
2. Login karo
3. New user create karo
4. Console (F12) check karo - success message dikhega
5. Email inbox me OTP check karo

---

## 🔧 **Agar Error Aaye:**

### **"npm: command not found"**
→ Node.js install karo: https://nodejs.org/

### **"supabase: command not found"**
→ Step 2 dobara run karo

### **"Not logged in"**
→ Step 3 dobara run karo

### **"Function not found"**
→ `supabase/functions/send-email/index.ts` file check karo (maine create kar di hai)

---

## 📞 **Help Chahiye?**

Agar koi step me problem aaye, to:
1. Error message copy karo
2. Mujhe batao
3. Main help karunga!

---

**Bas itna hi! 5 commands run karo aur email sending kaam karega!** 🎉


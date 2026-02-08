# 🚀 Step-by-Step Run Guide (Hindi/English)

## ✅ Good News!

**Supabase credentials already configured hain!** Aapke existing Supabase project ke credentials already files me hain.

---

## 📝 Step 1: Supabase Credentials Check (Optional)

### Agar Aap Same Supabase Use Kar Rahe Hain:
**Kuch nahi karna!** Credentials already set hain. ✅

### Agar Different Supabase Use Karna Hai:

#### **Vue.js Template:**
1. File open karo: `vue-starter-template/src/lib/supabase.js`
2. Line 3-4 me ye values update karo:
```javascript
const SUPABASE_URL = 'apna-supabase-url'
const SUPABASE_ANON_KEY = 'apna-anon-key'
```

#### **Next.js Template:**
1. File open karo: `nextjs-starter-template/lib/supabase.ts`
2. Line 3-4 me ye values update karo:
```typescript
const SUPABASE_URL = 'apna-supabase-url'
const SUPABASE_ANON_KEY = 'apna-anon-key'
```

**Note:** Agar aap same Supabase use kar rahe hain (jo pehle se use ho raha hai), to kuch change nahi karna!

---

## 🖥️ Step 2: Commands Kahan Run Karoon?

### **Answer: Windows PowerShell me!**

### **Method 1: PowerShell Open Karein**

1. **Windows Key + X** press karein
2. **"Windows PowerShell"** ya **"Terminal"** select karein
3. Ya **Start Menu** se **PowerShell** search karein

### **Method 2: Folder se Direct**

1. File Explorer me template folder me jao
2. Address bar me `powershell` type karein aur Enter
3. PowerShell automatically wahi folder me khul jayega

---

## 🎯 Step 3: Commands Run Karein

### **Option A: Vue.js Template**

PowerShell me ye commands copy-paste karein:

```powershell
# Step 1: Template folder me jao
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template"

# Step 2: Dependencies install (agar pehle nahi kiya)
npm install

# Step 3: Development server start karo
npm run dev
```

**Result:**
- Terminal me kuch aisa dikhega:
```
  VITE v5.x.x  ready in xxx ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

- Browser me automatically khul jayega ya manually `http://localhost:5173` open karo

---

### **Option B: Next.js Template**

PowerShell me ye commands copy-paste karein:

```powershell
# Step 1: Template folder me jao
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\nextjs-starter-template"

# Step 2: Dependencies install (agar pehle nahi kiya)
npm install

# Step 3: Development server start karo
npm run dev
```

**Result:**
- Terminal me kuch aisa dikhega:
```
  ▲ Next.js 14.x.x
  - Local:        http://localhost:3000
  - Ready in xxx ms
```

- Browser me automatically khul jayega ya manually `http://localhost:3000` open karo

---

## 📸 Visual Guide

### **PowerShell Window:**
```
Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\Users\shahf> 
```

### **After `cd` command:**
```
PS C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template> 
```

### **After `npm run dev`:**
```
PS C:\Users\shahf\...\vue-starter-template> npm run dev

  VITE v5.x.x  ready in 500 ms

  ➜  Local:   http://localhost:5173/
  ➜  press h to show help
```

---

## 🎯 Complete Example (Vue.js)

### **PowerShell me ye sab ek saath:**

```powershell
# Folder me jao
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template"

# Install (agar pehle nahi kiya)
npm install

# Run
npm run dev
```

**Agar sab theek hai, to browser automatically khul jayega!** ✅

---

## 🎯 Complete Example (Next.js)

### **PowerShell me ye sab ek saath:**

```powershell
# Folder me jao
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\nextjs-starter-template"

# Install (agar pehle nahi kiya)
npm install

# Run
npm run dev
```

**Agar sab theek hai, to browser automatically khul jayega!** ✅

---

## ⚠️ Common Issues & Solutions

### **Issue 1: "npm is not recognized"**
**Solution:**
- Node.js install nahi hai
- Download karo: https://nodejs.org/
- Install karo, phir PowerShell restart karo

### **Issue 2: "Cannot find path"**
**Solution:**
- Path check karo
- Quotes me path wrap karo: `"C:\Users\...\vue-starter-template"`

### **Issue 3: "Port already in use"**
**Solution:**
- Koi aur app port use kar raha hai
- Ya pehle wala server band karo (Ctrl+C)
- Phir se `npm run dev` run karo

### **Issue 4: "Module not found"**
**Solution:**
- `npm install` run karo
- `node_modules` folder check karo (bani honi chahiye)

---

## ✅ Quick Checklist

Before running:
- [ ] Node.js installed hai? (`node --version` check karo)
- [ ] Correct folder me ho? (`pwd` ya `Get-Location` se check karo)
- [ ] `npm install` pehle run kiya? (agar nahi, to pehle run karo)

---

## 🎉 Success Indicators

### **Vue.js:**
- Terminal me: `Local: http://localhost:5173/`
- Browser automatically khulta hai
- Home Portal page dikhta hai

### **Next.js:**
- Terminal me: `Local: http://localhost:3000`
- Browser automatically khulta hai
- Home Portal page dikhta hai

---

## 💡 Pro Tips

1. **PowerShell as Administrator** run karo (agar permission issues ho)
2. **Browser cache clear** karo (Ctrl+Shift+Delete)
3. **Hard refresh** karo (Ctrl+F5) agar changes nahi dikh rahe

---

## 🆘 Still Having Issues?

1. **Check Node.js:**
   ```powershell
   node --version
   npm --version
   ```
   Agar version nahi dikha, to Node.js install karo.

2. **Check Current Directory:**
   ```powershell
   Get-Location
   ```
   Agar wrong folder me ho, to `cd` se correct folder me jao.

3. **Clear and Reinstall:**
   ```powershell
   # node_modules delete karo
   Remove-Item -Recurse -Force node_modules
   
   # Phir se install karo
   npm install
   ```

---

## 🎯 Final Steps

1. ✅ PowerShell open karo
2. ✅ Correct path pe jao (`cd` command)
3. ✅ `npm install` (agar pehle nahi kiya)
4. ✅ `npm run dev` run karo
5. ✅ Browser me check karo!

**That's it!** 🚀

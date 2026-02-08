# Windows PowerShell Setup Guide

## ❌ Problem
Templates Desktop par nahi hain - wo Downloads folder me hain!

## ✅ Solution - Correct Path

### Step 1: Navigate to Correct Location

```powershell
# First, go to the Downloads folder where templates are located
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React"
```

### Step 2: Choose Your Template

#### Option A: Vue.js Template

```powershell
# Navigate to Vue.js template
cd vue-starter-template

# Install dependencies
npm install

# Run development server
npm run dev
```

#### Option B: Next.js Template

```powershell
# Navigate to Next.js template
cd nextjs-starter-template

# Install dependencies
npm install

# Run development server
npm run dev
```

---

## 🎯 Complete Commands (Copy-Paste Ready)

### For Vue.js:

```powershell
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template"
npm install
npm run dev
```

### For Next.js:

```powershell
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\nextjs-starter-template"
npm install
npm run dev
```

---

## 📍 Quick Check - Where Are Templates?

Templates yahan hain:
```
C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\
├── vue-starter-template\     ← Yahan hai!
└── nextjs-starter-template\ ← Yahan hai!
```

**NOT in Desktop!** ❌

---

## 🔧 Alternative: Use Full Path Directly

You can also use full path directly:

```powershell
# Vue.js - Direct path
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template"
npm install
npm run dev
```

---

## ✅ Verification

After `cd` command, check your location:

```powershell
# See current directory
pwd

# Or
Get-Location
```

You should see:
```
C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template
```

---

## 🚀 One-Line Commands (Easier)

### Vue.js:
```powershell
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template"; npm install; npm run dev
```

### Next.js:
```powershell
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\nextjs-starter-template"; npm install; npm run dev
```

---

## 💡 Pro Tip

Create a shortcut script:

**Create `run-vue.ps1`:**
```powershell
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\vue-starter-template"
npm run dev
```

**Create `run-nextjs.ps1`:**
```powershell
cd "C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\nextjs-starter-template"
npm run dev
```

Then just run: `.\run-vue.ps1` or `.\run-nextjs.ps1`

---

## 🎯 Summary

**Problem:** Templates Desktop me nahi the
**Solution:** Correct path use karo:
```
C:\Users\shahf\Downloads\Sakura_ERP_for Quality\ERP_Final - - Without_React\
```

**Now try again with correct path!** ✅

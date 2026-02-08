# Frontend Server Start Karein

## Problem
`localhost:5173` connection refused - Frontend server start nahi hua.

## Solution

### Method 1: ERP_KHOLO.bat Use Karein (Easiest)

**`ERP_KHOLO.bat`** file double-click karo - yeh automatically:
- ✅ Backend start karega
- ✅ Frontend start karega
- ✅ Browser khol dega

### Method 2: Manually Start Karein

**Terminal 1 - Backend:**
```powershell
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration\backend"
npm run dev
```

**Terminal 2 - Frontend (Naya Terminal):**
```powershell
cd "C:\Users\shahf\Downloads\ERP\Sakura_ERP_for Quality (Veu Based)\ERP_Final - - Without_React\sakura-erp-migration\frontend"
npm run dev
```

### Method 3: START_FRONTEND.bat Use Karein

**`START_FRONTEND.bat`** file double-click karo.

## Verify

Frontend start hone ke baad:
- Terminal mein dikhega: `Local: http://localhost:5173`
- Browser mein automatically khul jayega
- Ya manually: http://localhost:5173

## Important

**Dono servers chahiye:**
1. ✅ Backend (port 3000) - API ke liye
2. ✅ Frontend (port 5173) - UI ke liye

**Dono terminal windows band mat karo!**

---

**Frontend server start ho gaya hai - ab browser refresh karo!**


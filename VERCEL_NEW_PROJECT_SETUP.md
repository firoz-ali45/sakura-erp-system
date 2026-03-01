# 🆕 Naya Vercel Project – Step by Step (Clean Setup)

Puraani project chhod ke **naya project** banao, taaki auto deploy sahi se chalne lage.

---

## Step 1: GitHub repo ready karo (sirf main use karo)

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system-2"
git checkout main
git pull origin main
```

Confirm: `git branch` — sirf **main** pe ho, aur latest code ho.

---

## Step 2: Vercel pe naya project banao

1. **Vercel** kholo: https://vercel.com  
2. Login karo (GitHub se).
3. **Add New…** → **Project** (ya **Create a new project**).
4. **Import** section me **GitHub** choose karo.
5. Repository list me **firoz-ali45/sakura-erp-system** dhundho.
6. **Import** par click karo.

---

## Step 3: Project settings (yahi sabse zaroori)

Import ke baad **Configure Project** wale screen pe:

| Setting | Value (exact) |
|--------|----------------|
| **Project Name** | kuch bhi (e.g. `sakura-erp` ya `sakura-erp-system-miuq`) |
| **Framework Preset** | **Vite** (agar list me hai) ya **Other** |
| **Root Directory** | **Edit** click karo, ye path daalo: `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend` |
| **Build Command** | `npm run build` (default rehne do agar Vite/Other me already hai) |
| **Output Directory** | `dist` (default rehne do) |
| **Install Command** | `npm install` (default) |

**Root Directory** me space dhyan se:  
`ERP_Final` space `-` space `-` space `Without_React2` … (beech me **double space** hai).

**Deploy** button dabao.

---

## Step 4: Production branch = main

1. Deploy start hone ke baad **Go to Dashboard** (ya project open karo).
2. **Settings** → **Git**.
3. **Production Branch** = **main** (agar alag hai to `main` select karo, Save).

---

## Step 5: Test – auto deploy

1. Local me koi chhota change karo (e.g. README ya koi file).
2. Commit + push:
   ```powershell
   git add .
   git commit -m "test: trigger vercel deploy"
   git push origin main
   ```
3. **Vercel Dashboard** → **Deployments**.
4. 1–2 minute me naya deployment dikhna chahiye (Building → Ready).

Agar **Ready** ho gaya, to auto deploy sahi kaam kar raha hai.

---

## Step 6: Purana project (optional)

- Purana **sakura-erp-system-miuq** project Vercel me rehne do ya delete karo – tumhari marzi.
- Naye project ka URL alag hoga (e.g. `sakura-erp-xxx.vercel.app`).  
- Custom domain chahiye to naye project ke **Settings → Domains** me add kar sakte ho.

---

## Agar deploy fail ho (Error aaye)

1. **Deployments** → failed deployment → **View Function Logs** / **Build Logs**.
2. Error copy karo (screenshot bhi chalega).
3. **Root Directory** dubara check karo – path bilkul same ho, extra/missing space na ho.
4. Frontend folder me `package.json` me `"build": "npm run build"` ya `"build": "vite build"` hona chahiye (already hai).

---

## Short checklist

- [ ] GitHub repo: `main` branch pe ho, latest code pull kiya
- [ ] Vercel: New Project → Import **firoz-ali45/sakura-erp-system**
- [ ] **Root Directory** = `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`
- [ ] **Production Branch** = **main**
- [ ] Deploy → test push → deployment **Ready** dikhe

Iske baad **sirf main pe commit + push** karo — deploy khud chal jayega.

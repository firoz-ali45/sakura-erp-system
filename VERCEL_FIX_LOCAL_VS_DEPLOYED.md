# Vercel pe Changes Nahi Dikh Rahe — Fix Guide

## Problem
- **Local (localhost:5173):** Correct — minimal Create popup, L1 Approved buttons
- **Vercel (sakura-erp-system-miuq.vercel.app):** Old UI — complex Create modal, missing buttons

## Root Cause
Vercel GitHub integration **wrong Root Directory** se build kar raha hai, ya **purana cached build** serve kar raha hai.

---

## Fix 1: Vercel Root Directory (PRIORITY)

1. **Vercel Dashboard** → https://vercel.com
2. Project **sakura-erp-system-miuq** select karo (jo domain sakura-erp-system-miuq.vercel.app use karta hai)
3. **Settings** → **General**
4. **Root Directory** section:
   - **Edit** click karo
   - Ye path **exactly** paste karo (no extra spaces):

   ```
   ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
   ```

   - **Save** karo

5. **Deployments** tab → **Redeploy** (latest commit) — **"Clear cache and deploy"** select karo

---

## Fix 2: CLI se Direct Deploy (sakura-erp-system-miuq project)

CLI ne abhi **frontend** project par deploy kiya. Tumhe **sakura-erp-system-miuq** par deploy karna hai.

```powershell
cd "C:\Users\shahf\.cursor\worktrees\sakura-erp-system\gka\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"

# Pehli baar: link to correct project
npx vercel link

# Project choose karo: sakura-erp-system-miuq (ya jo bhi tumhara production project hai)

# Deploy
npx vercel --prod --yes
```

---

## Fix 3: Deploy Hook Check

commit-and-deploy.ps1 jo hook use karta hai — verify karo wo **sakura-erp-system-miuq** project ka hai:

- Vercel → sakura-erp-system-miuq → Settings → Git → Deploy Hooks
- Hook URL match karta hai?

---

## Verify After Fix

1. Vercel URL kholo: https://sakura-erp-system-miuq.vercel.app
2. **Create Transfer Order** click karo
3. **Expected:** Sirf Source + Destination dropdowns, Cancel, Save (NO Notes, NO Items)
4. **L1 Approved** TO open karo
5. **Expected:** Decline | Print | Accept (or Send Items) buttons top right

---

## Quick Checklist

| Step | Action |
|-----|--------|
| 1 | Vercel → sakura-erp-system-miuq → Settings → Root Directory |
| 2 | Set: `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend` |
| 3 | Save |
| 4 | Deployments → Redeploy → Clear cache |
| 5 | 2–3 min wait → Hard refresh (Ctrl+Shift+R) |

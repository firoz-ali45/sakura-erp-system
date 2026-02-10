# Vercel "Root Directory does not exist" — Fix

## Problem
Build fail: **The specified Root Directory "..." does not exist.**

## Cause
Vercel Project Settings mein **Root Directory** galat hai — path mein **extra spaces** ya typo.  
Sahi path mein **slash ke baad koi space nahi** hona chahiye.

---

## Fix (Vercel Dashboard)

1. **Vercel** → [vercel.com](https://vercel.com) → apna project **sakura-erp-system**.
2. **Settings** (top menu) → **General**.
3. **Root Directory** section:
   - **"Edit"** dabayein.
   - Purana path **delete** karein.
   - Neeche wala path **bilkul copy-paste** karein (space mat add karein):

   ```
   ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
   ```

   - **Important:** Slash ke baad space nahi — `Without_React2/ERP` sahi hai, `Without_React2/ ERP` galat.
4. **Save** karein.
5. **Deployments** → latest deployment pe **Redeploy** (ya naya commit push karke naya deploy).

---

## Verify path in repo
Repo root se frontend yahan hona chahiye:
- `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`
- Is folder ke andar `package.json` aur `vercel.json` hona chahiye.

---

## Agar phir bi fail ho
**Option: CLI se deploy** (Root Directory bypass — direct frontend folder se):

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system"
.\deploy-vercel-cli.ps1
```

Yeh script `ERP_Final - - Without_React2\...\frontend` mein chali jati hai aur `vercel --prod` chalati hai; isse Vercel ko sahi root mil jata hai.

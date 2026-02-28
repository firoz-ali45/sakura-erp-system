# 🚀 Deploy: Commit & Push se Auto Deploy

## Problem
- Commit & Push karne ke baad deploy nahi ho raha
- Vercel Production **main** branch se deploy karta hai
- Aap **fix/grn-batches** pe push karte ho → PR open hota hai, merge nahi hota
- Isliye Production deploy trigger nahi hota

## Solution: Ek Baar Vercel Setting Change Karo

### Step 1: Vercel Dashboard
1. https://vercel.com pe jao
2. **sakura-erp-system-miuq** project kholo
3. **Settings** → **Git** section

### Step 2: Production Branch Change
- **Production Branch** ko `main` se change karke **`fix/grn-batches`** kar do
- Save karo

### Result
Ab jab bhi tum **fix/grn-batches** pe **Commit & Push** karoge:
- Vercel automatically Production deploy karega
- Koi PR merge, koi extra step nahi
- **Commit & Push = Deploy** ✅

---

## Alternative: Main pe Direct Push (Agar tum hi solo developer ho)

Agar tum chahte ho ki **main** hi production rahe:
1. PR #4 **Merge** karo (GitHub pe "Merge pull request" button)
2. Phir hamesha **main** pe push karo: `git push origin main`
3. Vercel main se deploy karega

---

## Build Error Fix (vercel.json schema)

**Important:** `rootDirectory` **vercel.json mein NAHI dalna**. Vercel schema mein ye property valid nahi hai – isliye "should NOT have additional property rootDirectory" error aata hai. Root Directory **sirf Vercel Dashboard** → Settings → Build and Deployment mein set karo (value: `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`).

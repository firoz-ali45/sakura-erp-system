# Vercel deploy nahi ho raha – yeh cheezein check karo

## 1. Vercel Project → Git settings

- **Settings** → **Git** (ya **Build and Deployment**)
- **Production Branch** = `main` hona chahiye. Agar kuch aur hai (e.g. `fix/grn-batches`) to **main** pe set karo taaki `main` pe push par production deploy ho.

## 2. Root Directory (pehle se set hai)

- **Settings** → **Build and Deployment** → **Root Directory**
- Value yeh honi chahiye (bilkul aise):
  ```
  ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
  ```
- **Save** karo.

## 3. Naya deploy trigger karna

- Purani failed deployment pe **Redeploy** mat karo (Vercel bolta hai "try from a fresh commit").
- **Naya commit push karo** (main pe). Phir **Deployments** list mein nayi deployment upar aani chahiye.
- Agar list mein sab purani (1h ago, 2h ago) hi dikhen to **Status** filter hatao: **All** / **Ready + Error** dono select karke dekho.

## 4. CLI se direct deploy (build error dekhne ke liye)

Agar phir bhi deploy nahi hota, terminal se build chalake error dekh sakte ho:

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system\sakura-erp-system-3\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"
npx vercel --prod
```

- Pehle `npm i -g vercel` ya `npx vercel login` se login karo.
- Is se yahi project ka production deploy hoga aur build ka error terminal mein dikhega.

## 5. Repo mein vercel.json

- **Root** aur **frontend** dono `vercel.json` mein `rootDirectory` **nahi** hona chahiye (ab nahi hai).
- `$schema` add kiya hai taaki invalid properties reject hon.

---

**Short:** Production Branch = **main**, Root Directory sahi path pe set ho, naya commit push karo; agar phir bhi fail ho to CLI wala step 4 chala ke error batao.

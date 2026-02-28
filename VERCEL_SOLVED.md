# Vercel deploy – final fix (Commit & Push = Auto Deploy)

## 1. Schema error fix (rootDirectory)

**Error:** `The vercel.json schema validation failed with the following message: should NOT have additional property rootDirectory`

**Cause:** `rootDirectory` is **not** a valid property in `vercel.json`. Vercel schema allows only specific keys (buildCommand, framework, rewrites, headers, etc.). Root Directory is configured **only** in the Vercel Dashboard.

**Fix (done in this repo):**
- **Kisi bhi `vercel.json` mein `rootDirectory` mat dalna.** Sab `vercel.json` files mein `$schema` add hai taaki invalid properties IDE/build time pe hi catch hon.
- **Root Directory sirf Vercel Dashboard mein set karo:**  
  **Settings** → **Build and Deployment** → **Root Directory**  
  Value (copy-paste):  
  `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`  
  **Save** karo.

## 2. Auto deploy (Commit & Push)

- **Git** repo `firoz-ali45/sakura-erp-system` Vercel project **sakura-erp-system-miuq** se connected hai.
- **Production Branch** = `main` (Settings → Git / Environments).
- **Commit & push to `main`** → Vercel automatically naya deployment start karega.
- Agar deployment list mein purane hi deployments dikhen to **naya commit push karo** (empty commit bhi chalega):  
  `git commit --allow-empty -m "chore: trigger Vercel deploy" && git push origin main`

## 3. Checklist (deploy fail ho to)

| # | Check | Action |
|---|--------|--------|
| 1 | `vercel.json` mein `rootDirectory` nahi hona chahiye | Repo mein koi bhi `vercel.json` open karke confirm karo – agar hai to hata do |
| 2 | Root Directory Dashboard mein set hai | Vercel → sakura-erp-system-miuq → Settings → Build and Deployment → Root Directory = `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend` |
| 3 | Production branch = main | Settings → Git / Environments |
| 4 | Naya deploy trigger | Naya commit push karo; purani failed deployment pe "Redeploy" se bhi try kar sakte ho |

In sab ke baad **Commit & Push = Auto Deploy** hona chahiye.

# Vercel par update nahi dikh raha — step-by-step check

## 1. Naya deployment aa raha hai ya nahi

- **Vercel Dashboard** → apna project → **Deployments**.
- Ab **ek naya commit push karo** (e.g. `.\sync-to-git.ps1`).
- 1–2 minute me **Deployments** list me **nayi row** aani chahiye (jaise "Sync: 2026-02-09 ...").

**Agar nayi deployment dikhe:**
- Us row par click karo → **Building** / **Ready** / **Error** kya hai?
- **Error** ho to **View Build Logs** kholo — jo error aaye woh copy karke bhejo.

**Agar nayi deployment bilkul nahi aa rahi:**
- Matlab GitHub se Vercel tak trigger nahi ja raha.
- **Settings** → **Git** → **Connected Git Repository** check karo: repo `firoz-ali45/sakura-erp-system` hi hona chahiye.
- **Production Branch** = `main` hona chahiye.

---

## 2. Root Directory exact path (copy-paste)

**Settings** → **General** → **Root Directory** → Edit.

Bilkul ye paste karo (space / slash exact rakhna):

```
ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
```

- Forward slash (`/`) use karo, backslash (`\`) nahi.
- `ERP_Final - - Without_React2` me do space hai (dash ke dono taraf).
- Save karke **Redeploy** karo.

---

## 3. Kaunsi site khol rahe ho

- **Production URL** (jahan update chahiye):  
  Vercel → **Settings** → **Domains** ya deployment par jo **Production** URL hai (e.g. `sakura-erp-system.vercel.app` ya `sakura-erp-system-miuq.vercel.app`).
- Agar do project hain (do alag URL), to jis project me Root Directory set kiya hai, **us project ka** URL kholna hai.

---

## 4. Force redeploy (fresh build)

- **Deployments** → sabse upar wali deployment → **⋯** (three dots) → **Redeploy**.
- Option: **Redeploy with existing Build Cache** = **OFF** (taaki purana cache na chale).
- Build complete hone tak wait karo, phir Production URL open karke check karo.

---

## 5. Build log me kya dikhna chahiye

Redeploy par **Build Logs** me aisa kuch hona chahiye:

- `Installing dependencies...` (frontend folder me)
- `Running "npm run build"` ya `node node_modules/vite/bin/vite.js build`
- `Build Completed in ...`

Agar yahan **error** aaye (e.g. "No such file or directory", "package.json not found") — matlab Root Directory galat hai ya path me typo.

---

## Short checklist

| # | Check | Kya karna hai |
|---|--------|----------------|
| 1 | Naya push → naya deployment? | Deployments list me nayi row aani chahiye. |
| 2 | Root Directory | Exact: `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend` |
| 3 | Production branch | `main` |
| 4 | Sahi URL | Jis project me Root set kiya, usi ka production URL kholna. |
| 5 | Redeploy | Ek baar "Redeploy" (cache off) karke build log check karo. |

---

## 6. Agar phir bhi na chale — Root Directory reset

Kabhi-kabhi setting stick nahi hoti. Ye try karo:

1. **Root Directory** → **Edit** → value **clear** karo (khali chhod do) → **Save**.
2. Phir dubara **Edit** → ye exact paste karo:  
   `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`  
   → **Save**.
3. **Deployments** → **Redeploy** (cache off).

---

Jo bhi step fail ho (naya deploy nahi aana, build fail, wrong URL) — us step ka screenshot ya error message bhejo, us hisaab se next fix bata sakte hain.

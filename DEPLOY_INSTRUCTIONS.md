# 🚀 Sakura ERP – Deploy: Sirf Main Branch, Auto Deploy

## Tumhara Goal (Single source of truth)

- **Sirf `main` branch use karo.** Koi aur branch (fix/grn-batches, etc.) use mat karo.
- **Commit & Push `main` pe karo** → Vercel **automatically** Production deploy karega.
- Dusre branches se kuch nahi chahiye – saara code **main** me hi rahega.

---

## 1. Vercel Dashboard – Ek baar ye confirm karo

### Root Directory (zaroori)

1. **Vercel** → **sakura-erp-system-miuq** → **Settings** → **Build and Deployment**
2. **Root Directory** ye exact set ho:
   ```
   ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
   ```
3. **Save** karo.

### Production branch = main

1. **Settings** → **Environments**
2. **Production** ke against **Branch** = **`main`** hona chahiye (change mat karo agar already main hai).
3. **Preview** = "All unassigned git branches" rakh sakte ho (ya ignore karo – tum sirf main use karoge).

### Git connection

1. **Settings** → **Git**
2. **Connected Git Repository** = `firoz-ali45/sakura-erp-system` (Connected) – ye sahi hai.
3. "Deployments for any commits pushed" wala option ON rehna chahiye.

---

## 2. vercel.json – Important

- **Root Directory** kabhi bhi kisi `vercel.json` file me **mat** likho. Schema error aata hai.
- Root Directory **sirf** Vercel Dashboard me set karo (upar wala path).
- Repo me jo `vercel.json` use hota hai (frontend folder wala), usme `$schema` hai, `rootDirectory` **nahi** hai.

---

## 3. Daily workflow – Commit & Push = Deploy

```bash
# 1. Main branch par ho
git checkout main

# 2. Changes karo, phir:
git add .
git commit -m "your message"
git push origin main
```

**Push ke 1–2 minute baad** Vercel **Deployments** me naya deployment dikhega (Building → Ready).

---

## 4. Agar deploy "Error" dikhe

1. **Vercel Dashboard** → **Deployments** → us deployment par click karo.
2. **Building** / **Logs** open karke **error message** dekho.
3. Common issues:
   - **Root Directory** galat hai → Step 1 dubara check karo.
   - **Build command / Output directory** – frontend folder me `vercel.json` me `buildCommand: "npm run build"`, `outputDirectory: "dist"` sahi hona chahiye (already set hai).
   - Node/npm version – Vercel usually auto-detect karta hai.

---

## 5. Deploy Hook (optional backup)

Agar Git integration kabhi trigger na kare, to **Deploy Hook** se manually deploy trigger kar sakte ho:

- **URL:**  
  `https://api.vercel.com/v1/integrations/deploy/prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc/6DAzsrbj0c`
- Browser me open karo ya:
  ```powershell
  Invoke-WebRequest -Uri "https://api.vercel.com/v1/integrations/deploy/prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc/6DAzsrbj0c" -Method GET -UseBasicParsing
  ```
- Ye **main** branch ke liye deploy trigger karega (hook **main** pe set hai).

---

## 6. Branches ka confusion khatam

- **Main** = production. Yahi use karo.
- Purane branches (fix/grn-batches, etc.) ko GitHub pe **delete** kar sakte ho agar chahe to – ab zaroori nahi.
- Naya kaam: **main** pe branch banao ya direct **main** pe commit karo, phir `git push origin main` → deploy ho jayega.

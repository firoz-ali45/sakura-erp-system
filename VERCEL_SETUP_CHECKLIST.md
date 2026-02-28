# Vercel Setup – 100% Sahi Karne ka Checklist

## Root cause (problem kya thi)

1. **Commit to main ho raha tha, deploy nahi**  
   - Vercel Git integration connected hai, lekin deployments **Error** dikha rahe the.  
   - Matlab: trigger ho raha hai ya to build fail ho raha hai, ya koi setting galat hai.

2. **Dusre branches se bhi deploy ho rahe the**  
   - **Preview** environment "All unassigned git branches" pe set tha, isliye `fix/grn-batches` jaise branches pe bhi preview deploy hota tha.  
   - Ab tum **sirf main** use karoge, to wo deployments ignore kar sakte ho.

3. **Fix**  
   - Production = **main** (ye sahi hai).  
   - Root Directory = **sirf Dashboard me** set karo (vercel.json me mat dalna).  
   - **Backup:** GitHub Action add kiya hai – `main` pe push hote hi Vercel Deploy Hook call hoga.

---

## Ek baar ye sab verify karo (Vercel Dashboard)

| Setting | Location | Expected value |
|--------|----------|----------------|
| **Root Directory** | Settings → Build and Deployment | `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend` |
| **Production branch** | Settings → Environments → Production | `main` |
| **Git repo** | Settings → Git | `firoz-ali45/sakura-erp-system` (Connected) |
| **Build Command** | (optional, frontend vercel.json me hai) | `npm run build` |
| **Output Directory** | (optional, frontend vercel.json me hai) | `dist` |

---

## Agar ab bhi deploy Error aaye

1. **Deployments** → failed deployment → **View Build Logs**.
2. Error message copy karo (e.g. "rootDirectory", "module not found", "command failed").
3. **Root Directory** path me typo to nahi (extra space, slash) – exact same path use karo jo upar diya hai.
4. **Deploy Hook** se manual trigger karke dekho:  
   `https://api.vercel.com/v1/integrations/deploy/prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc/6DAzsrbj0c`  
   Agar hook se bhi same error aaye to problem build/config me hai; logs se fix karo.

---

## Short summary

- **Sirf `main` branch use karo.** Push = Auto deploy (Git + backup GitHub Action).
- **Root Directory** = sirf Vercel Dashboard me, **vercel.json me kabhi mat likhna**.
- Error aaye to **Build Logs** dekho, phir is checklist se match karo.

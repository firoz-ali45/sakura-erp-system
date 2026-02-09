# Deploy Hook — Project ID verify karo

Script me jo URL hai usme **Project ID** ye hai:  
`prj_VsTQWkUyDQqIogM3cqKUK8nrmuzc`

Agar ye **sakura-erp-system-miuq** ka ID nahi hai, to deployment doosre project me ja rahi hai.

---

## Step 1: Sakura-erp-system-miuq ka sahi hook URL lao

1. Browser me **sirf ye** kholo: https://vercel.com/firoz-ali45s-projects/sakura-erp-system-miuq/settings/git  
   (Direct isi URL se jao taaki galat project na khule.)
2. Neeche **Deploy Hooks** me **Create Hook**.
3. Name: `Script trigger`, Branch: `main` → **Create**.
4. Jo URL dikhe, use **Copy** karo. Us URL me `prj_` ke baad jo 25 character ka code hai, wahi **is project ka ID** hai.

---

## Step 2: Compare karo

- Script me (line 6) URL me jo `prj_xxxxx` hai = **pehla ID**
- Abhi copy kiye hook me jo `prj_xxxxx` hai = **dusra ID**

**Agar dono alag hain** → script me **purana URL hata kar naya wala (Step 1 se copy) paste karo**, save karo, phir `.\trigger-vercel.ps1` chalao. Deployment ab **sakura-erp-system-miuq** me aani chahiye.

**Agar dono same hain** → phir bhi deployment nahi dikh rahi to next step (Vercel CLI) use karo.

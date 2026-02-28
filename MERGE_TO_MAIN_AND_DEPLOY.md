# Main par merge karke Vercel deploy trigger karo

Yeh steps **ek baar** apne **main repo** (Downloads path) me chalao. Isse `main` update hoga aur Vercel pe **naya deployment** trigger hoga.

## Commands (PowerShell – Downloads wale folder me)

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system\sakura-erp-system-3"
git fetch origin
git checkout main
git merge origin/fix/grn-batches -m "Merge fix/grn-batches: Vercel rootDirectory fix - single vercel.json in frontend"
git push origin main
```

## Result

- `main` par latest fix/grn-batches changes aa jayenge (vercel.json fix + docs).
- Push ke 1–2 min baad **Vercel** → **sakura-erp-system-miuq** → **Deployments** me naya deployment dikhna chahiye.
- Agar **sakura-erp-system-miuq** GitHub pe ab bhi "inactive" dikhe to pehle **Vercel** → **Settings** → **Git** me is project ko **firoz-ali45/sakura-erp-system** se connect karo, phir upar wale commands dubara chalao.

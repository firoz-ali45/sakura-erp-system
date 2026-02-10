# sakura-erp-system-miuq — Production Deploy (Actual Project)

Yahi **actual project** hai. Isko **Root Directory empty** rakhte hue deploy karte hain.

---

## Redeploy latest version (same way, change mat karo)

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system"
.\sync-to-git.ps1
.\deploy-vercel-cli.ps1
```

1. **sync-to-git.ps1** — local changes commit + push (Git repo update).
2. **deploy-vercel-cli.ps1** — frontend folder mein jaa kar `vercel --prod` chalata hai → **sakura-erp-system-miuq** par deploy.

---

## Kyun way change nahi karna

- Vercel par is project ka **Root Directory empty** hai.
- Deploy **CLI se** hota hai, aur CLI **frontend folder ke andar** se run hoti hai (`ERP_Final - - Without_React2\...\frontend`).
- Isliye Vercel ko build sahi folder se mil jati hai; Root Directory ki zaroorat nahi.
- **Git push se auto-deploy** is project par depend mat karo — hamesha **sync + CLI deploy** use karo.

---

## Pehli baar / link toot gaya ho to

Frontend folder mein jaa kar project link karo:

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"
npx vercel link
# sakura-erp-system-miuq choose karo
```

Phir wapas repo root se: `.\deploy-vercel-cli.ps1`

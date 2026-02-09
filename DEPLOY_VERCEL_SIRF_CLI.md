# Deploy Hook / Push kaam na kare — sirf CLI se deploy (reliable)

Jab bhi tumhe **latest code Vercel par dikhana** ho, ye steps follow karo. Hook / push par depend mat karo.

---

## Pehli baar (sirf ek baar)

### 1. Vercel login

PowerShell me:

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"
npx vercel login
```

Browser khulega — Vercel se login karo (GitHub wala hi account).

### 2. Project link karo

```powershell
npx vercel link
```

- **Set up and link?** → **Y**
- **Which scope?** → apna account (firoz-ali45) choose karo
- **Link to existing project?** → **Y**
- **Project name?** → **sakura-erp-system-miuq** type karo ya list me se choose karo

Bas. Ab ye folder hamesha isi project se linked rahega.

---

## Ab se har baar deploy (2 commands)

Jab bhi Git push karke Vercel par latest dikhana ho:

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system"
.\sync-to-git.ps1
.\deploy-vercel-cli.ps1
```

Ya agar pehle hi push kar chuke ho to sirf:

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system"
.\deploy-vercel-cli.ps1
```

CLI **local frontend folder** ka code upload karega aur **sakura-erp-system-miuq** me nayi deployment banayega — **Deployments** me nayi row dikhegi aur site update ho jayegi.

---

## Short

| Problem | Solution |
|--------|----------|
| Hook / push se deployment nahi dikh rahi | Ab deploy **sirf CLI** se karo: pehli baar `vercel login` + `vercel link`, phir har baar `.\deploy-vercel-cli.ps1` |

Hook ko ab ignore karo — ye tareeka zyada reliable hai.

---

## Agar error aaye: "The provided path ... does not exist"

1. **Vercel Dashboard** → **sakura-erp-system-miuq** → **Settings** → **General**.
2. **Root Directory** — agar koi path set hai (jaise `ERP_Final - - Without_React2/.../frontend`) to use **clear** kar do (khali chhod do), **Save** karo.
3. Phir dubara chalao: `.\deploy-vercel-cli.ps1`

CLI se deploy karte waqt tum **frontend folder** se upload karte ho, isliye project ka Root Directory **khali** hona chahiye (CLI apna root bhejta hai).

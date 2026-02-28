# Vercel par naya deployment nahi aa raha – fix checklist

Commit push ho raha hai lekin Vercel pe naya deployment nahi dikh raha. Neeche steps follow karo.

---

## 1. GitHub Webhook check karo

1. **GitHub** → repo **firoz-ali45/sakura-erp-system** → **Settings** → **Webhooks**
2. Dekho koi **Vercel** wala webhook hai (URL mein `vercel.com` ya `vercel.app`)
3. Us pe click karo → neeche **Recent Deliveries** dekho
   - Agar **failed** (red) hai to delivery pe click karke error dekho
   - Agar koi webhook hi nahi hai to Vercel connect nahi hai (Step 2 karo)

---

## 2. Vercel Git connection dobara set karo

1. **Vercel** → project **sakura-erp-system-miuq** → **Settings** → **Git**
2. Agar "Connected to GitHub" dikhe to **Disconnect** karo, phir dubara **Connect** karke same repo select karo
3. Confirm karo **Production Branch** = `main` (Settings → Environments)

---

## 3. Do Vercel projects ho to

Tumhare paas **sakura-erp-system-miuq** aur **sakura-erp-system** dono ho sakte hain.

1. **Vercel Dashboard** → **Projects** list kholo
2. Dono projects kholke **Deployments** dekho
3. Jis project mein **recent commits** (1–2 min purane) ki deployments dikh rahi hon, wahi GitHub se connected hai
4. Jo project tum dekh rahe ho (miuq) uski **Settings → Git** mein confirm karo ki yahi repo **firoz-ali45/sakura-erp-system** connected hai

---

## 4. Deploy Hook se manual trigger (abhi deploy ke liye)

Jab tak auto-deploy fix nahi hota:

1. **Vercel** → **sakura-erp-system-miuq** → **Settings** → **Git** → **Deploy Hooks**
2. **Sakura_ERP** ke saamne **Copy** (URL copy karo)
3. Browser new tab mein woh URL paste karke **Enter** dabao
4. **Deployments** pe jao – 1–2 min mein naya deployment (Building → Ready/Error) dikhna chahiye

PowerShell se:
```powershell
Invoke-WebRequest -Uri "PASTE_COPIED_URL_HERE" -Method POST
```
(`-Uri` aur URL ke beech space zaroori hai.)

---

## 5. Root Directory sahi hai na

**Vercel** → **Settings** → **Build and Deployment** → **Root Directory**

Yeh path bilkul aisa hona chahiye (copy-paste karo):
```
ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
```
(har jagah space–dash–space ` - `, sirf `--` nahi.)

---

In sab ke baad bhi naya deployment na aaye to GitHub Webhooks page ka screenshot (Recent Deliveries) bhejo.

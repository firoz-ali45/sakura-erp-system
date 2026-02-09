# Vercel Deploy Hook — Push ke baad latest version deploy karne ke liye

Jab **push se Vercel par naya deployment nahi banta** (hamesha purana commit `bb006eb` hi build ho raha hai), tab **Deploy Hook** use karo. Isse tum **latest commit** se deploy trigger kar sakte ho.

---

## 1. Vercel me Deploy Hook banao

1. **Vercel Dashboard** → apna project **sakura-erp-system-miuq**.
2. **Settings** → left side **Git** scroll karo, ya **Integrations**.
3. **Deploy Hooks** dhundho (Git section me ya Integrations me).
4. **Create Hook**:
   - **Name**: `Deploy from script` (ya kuch bhi).
   - **Branch**: `main`.
5. **Create** → ek **URL** milegi, jaise:
   ```
   https://api.vercel.com/v1/integrations/deploy/xxxxx/yyyyy
   ```
6. Is URL ko **copy** karo.

---

## 2. Script me URL set karo

**Option A – Script me direct paste**

1. Open `trigger-vercel.ps1`.
2. Line jahan likha hai `PASTE_YOUR_VERCEL_DEPLOY_HOOK_URL_HERE` — usko **apni hook URL** se replace karo (quotes me):
   ```powershell
   $hookUrl = "https://api.vercel.com/v1/integrations/deploy/xxxxx/yyyyy"
   ```

**Option B – Environment variable (zyada safe)**

PowerShell me ek baar set karo (session ke liye):

```powershell
$env:VERCEL_DEPLOY_HOOK_URL = "https://api.vercel.com/v1/integrations/deploy/xxxxx/yyyyy"
```

Ya **permanent** (user env):  
Windows → Environment Variables → User → New → Name: `VERCEL_DEPLOY_HOOK_URL`, Value: apni URL.

---

## 3. Kaise use karo

**Pehle push, phir trigger:**

```powershell
cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system"
.\sync-to-git.ps1
.\trigger-vercel.ps1
```

- `sync-to-git.ps1` → Git repo update (commit + push).
- `trigger-vercel.ps1` → Vercel ko bolo **latest commit** se deploy karo.

1–2 minute me **https://sakura-erp-system-miuq.vercel.app/** par latest version dikhni chahiye.

---

## 4. Kyun kaam karta hai

- **Push** se Vercel tak webhook theek se nahi ja raha, isliye naya deployment nahi banta.
- **Deploy Hook** ek direct URL hai — jab bhi tum is URL ko **POST** karte ho, Vercel **main branch ka latest commit** uthata hai aur usse naya deployment banata hai.
- Isliye push ke baad hook run karte hi **latest code** Vercel par deploy ho jata hai.

---

## 5. Baad me GitHub → Vercel auto-deploy fix karna

Jab time mile:

- **GitHub** → **Settings** → **Applications** → **Vercel** → repo access check karo.
- **Vercel** → Project → **Settings** → **Git** → Connected repo = `firoz-ali45/sakura-erp-system`, Branch = `main`.

Jab ye sahi ho jaye, har push par automatically naya deployment banega; phir bhi Deploy Hook optional rahega (manual trigger ke liye).

# 404 NOT_FOUND — Vercel par fix

Root Directory set hone ke baad bhi **404: NOT_FOUND** aa raha ho to ye steps follow karein.

---

## Permission denied (vite: Permission denied) — FIX APPLIED

Agar build log me ye error aaye:
```text
sh: line 1: .../node_modules/.bin/vite: Permission denied
Error: Command "npm run build" exited with 126
```

**Reason:** Path me spaces (`ERP_Final - - Without_React2`) ki wajah se Linux/Vercel par `.bin/vite` execute nahi hota.

**Fix (do BOTH):**

1. **Vercel override (sabse tez — abhi karein):**  
   **Settings** → **Build and Deployment** → **Build Command** → **Override** on karein, value daalein:
   ```bash
   node node_modules/vite/bin/vite.js build
   ```
   Save → **Deployments** → latest → **Redeploy**. Isse GitHub bina push kiye build pass ho sakti hai.

2. **Repo fix (baad me):** `frontend/package.json` me build script:
   ```json
   "build": "node node_modules/vite/bin/vite.js build"
   ```
   Is change ko commit + push karein taake future deploys bhi theek rahein.

---

## Step 1: Build logs dekhein

1. **Vercel Dashboard** → apna project **sakura-erp-system**.
2. **Deployments** tab → sabse latest deployment pe click.
3. **Building** / **Logs** section open karein.

**Agar build FAIL (red) hai:**  
- 404 isliye aa raha hai — build complete nahi hua, `dist` bana hi nahi.
- Log me error dikhega (e.g. `npm install` fail, ya `vite build` error).
- Us error ko fix karein (Node version 18+, ya dependency fix).

**Agar build PASS (green) hai:** Step 2 pe jayein.

---

## Step 2: Root Directory exact karein

1. **Settings** → **General**.
2. **Root Directory** — ye **bilkul exact** hona chahiye (copy-paste karein):

   ```
   ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
   ```

3. **Important:**
   - Na start me `/`, na end me `/`.
   - Beech me **do spaces** hain: `ERP_Final - - Without_React2` (Final ke baad space, dash, space, Without).
4. **Save** karein.
5. **Deployments** → latest → **Redeploy** karein.

---

## Step 3: Build & Output override karein

1. **Settings** → **Build & Development Settings**.
2. **Override** enable karein aur set karein:

   | Field | Value |
   |-------|--------|
   | Build Command | `npm run build` |
   | Output Directory | `dist` |
   | Install Command | `npm install` |

3. **Save** → phir **Redeploy**.

---

## Step 4: GitHub pe path check karein

Agar ye path GitHub repo me **exist nahi karta**, to Vercel ko folder milta hi nahi → 404.

1. GitHub par repo **firoz-ali45/sakura-erp-system** open karein.
2. Folders dekhein: **ERP_Final - - Without_React2** → **ERP_Final - - Without_React** → **sakura-erp-migration** → **frontend**.
3. **frontend** ke andar `package.json` aur `index.html` hona chahiye.

Agar ye folders **nahi dikhen** (commit/push nahi hue):  
- Un folders ko commit karke push karein.  
- Phir Vercel me **Redeploy** karein.

---

## Step 5: Code update (ho chuka hai)

`frontend/vercel.json` me ab ye add ho chuka hai:

- `"buildCommand": "npm run build"`
- `"outputDirectory": "dist"`

Is se Vercel clearly `dist` use karega. **Is file ko commit + push karein**, phir Vercel se **Redeploy** karein.

---

## Summary

| Check | Action |
|-------|--------|
| Build fail? | Logs me error dekhein, fix karein (Node 18+, deps). |
| Root path | Exact copy-paste, no extra slash, Save + Redeploy. |
| Build/Output | Override: Build = `npm run build`, Output = `dist`, Save + Redeploy. |
| Path GitHub pe? | frontend folder tak repo me hona chahiye; nahi to commit/push + Redeploy. |
| vercel.json | buildCommand + outputDirectory add ho chuke — commit/push + Redeploy. |

In sab ke baad bhi 404 aaye to Vercel build log ka error message bhejein (screenshot ya text).

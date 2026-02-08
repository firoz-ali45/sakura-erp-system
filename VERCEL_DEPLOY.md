# Sakura ERP — Vercel par Deploy kaise karein

Is system ko **Vercel** par deploy karne ke liye ye steps follow karein.

---

## Option A: Vercel Dashboard se (Recommended)

### 1. Vercel par project import karein

1. [vercel.com](https://vercel.com) par login karein (GitHub se).
2. **Add New** → **Project**.
3. Is repo ko connect karein (GitHub/GitLab/Bitbucket).
4. **Root Directory** set karein:
   ```
   ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
   ```
   Ya agar aap repo ke andar sirf ye folder copy karke alag repo banaate hain, to root hi `./` rakh sakte hain.

### 2. Build settings (auto-detect ho sakte hain)

| Setting | Value |
|--------|--------|
| **Framework Preset** | Vite |
| **Build Command** | `npm run build` |
| **Output Directory** | `dist` |
| **Install Command** | `npm install` |

`vercel.json` isi folder mein hai, isliye Vercel inhe use karega.

### 3. Environment variables (optional)

Agar aap Supabase URL/Key env se dena chahein (recommended for production):

| Name | Value | Notes |
|------|--------|------|
| `VITE_SUPABASE_URL` | `https://kexwnurwavszvmlpifsf.supabase.co` | Optional – abhi code mein hardcoded hai |
| `VITE_SUPABASE_ANON_KEY` | (apna anon key) | Optional – abhi code mein hardcoded hai |

Abhi app hardcoded Supabase use karti hai; env use karne ke liye `src/services/supabase.js` mein `import.meta.env.VITE_SUPABASE_URL` use karna hoga.

### 4. Deploy

**Deploy** button dabayein. Build complete hone ke baad aapko URL milega, jaise:  
`https://sakura-erp-xxxx.vercel.app`

---

## Option B: Vercel CLI se

### 1. CLI install karein

```bash
npm i -g vercel
```

### 2. Frontend folder mein jayein

```bash
cd "ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend"
```

### 3. Deploy run karein

```bash
vercel
```

Pehli baar poochega: link to existing project? **N** (new project).  
Phir **Set up and deploy?** → **Y**.  
Root directory confirm karein: **./** (current folder).

Production deploy:

```bash
vercel --prod
```

---

## Important notes

- **Backend**: Database aur Auth **Supabase** par hi rahenge (Supabase cloud). Vercel sirf **frontend** (Vue SPA) host karega.
- **SPA routing**: `vercel.json` mein rewrites se saari routes `index.html` par jaati hain, isliye direct URL / refresh kaam karega.
- **Root Directory**: Agar repo root se deploy karte hain (bina root directory change kiye), to **Root Directory** zaroor set karein:  
  `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fail – `npm install` error | Node version 18+ set karein (Vercel → Project Settings → General → Node.js Version). |
| 404 on refresh / direct URL | `vercel.json` rewrites check karein; destination `/index.html` honi chahiye. |
| Supabase connection fail | Browser console dekhein; Supabase URL/Key sahi hon. Agar env use karte hain to `VITE_` prefix zaroori hai. |
| Blank page | Build output `dist` hai ya nahi check karein; Console me JavaScript errors dekhein. |

---

## Summary

1. Vercel par project add karein.
2. **Root Directory** = `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`.
3. Build = `npm run build`, Output = `dist`.
4. Deploy karein — frontend live ho jayegi; Supabase backend pehle se cloud par hai.

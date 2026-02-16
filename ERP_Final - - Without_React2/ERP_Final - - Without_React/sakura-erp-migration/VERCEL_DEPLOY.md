# Deploy Sakura ERP on Vercel

## Quick Deploy

### Option A: Deploy from GitHub (recommended)

1. **Push your code to GitHub** (if not already).

2. **Go to [vercel.com](https://vercel.com)** → Sign in → **Add New Project**.

3. **Import** your repository.

4. **Configure:**
   - **Root Directory:** `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`
   - **Framework Preset:** Vite (auto-detected)
   - **Build Command:** `npm run build`
   - **Output Directory:** `dist`

5. **Environment Variables** (optional; defaults work if you keep current Supabase):
   - `VITE_SUPABASE_URL` – your Supabase project URL
   - `VITE_SUPABASE_ANON_KEY` – your Supabase anon/public key

6. Click **Deploy**.

---

### Option B: Deploy from local (Vercel CLI)

```bash
# Install Vercel CLI
npm i -g vercel

# Go to frontend folder
cd "ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend"

# Deploy (first time: login + project setup)
vercel

# Production deploy
vercel --prod
```

---

## Supabase configuration

1. In **Supabase Dashboard** → **Settings** → **API**:
   - Add your Vercel domain to **Site URL** (e.g. `https://your-app.vercel.app`)
   - Add to **Redirect URLs** if using auth: `https://your-app.vercel.app/**`

2. **CORS:** Supabase allows all origins by default; no extra CORS setup needed.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| 404 on refresh | SPA rewrites in `vercel.json` should route all paths to `index.html` |
| Build fails | Run `npm run build` locally and fix any errors |
| Supabase connection fails | Check `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel env vars |
| Blank page | Check browser console; ensure `base: '/'` in `vite.config.js` |

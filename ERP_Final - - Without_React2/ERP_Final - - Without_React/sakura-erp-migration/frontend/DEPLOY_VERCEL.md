# Deploy Sakura ERP on Vercel

## Prerequisites

- [Vercel account](https://vercel.com)
- Git repository (GitHub, GitLab, or Bitbucket)
- Supabase project URL and anon key

---

## Step 1: Push to Git

Ensure your code is in a Git repository:

```bash
cd "ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend"
git init
git add .
git commit -m "Initial commit"
git remote add origin <your-repo-url>
git push -u origin main
```

---

## Step 2: Import Project on Vercel

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import your Git repository
3. **Root Directory**: Set to `frontend` (or the path to the frontend folder if deploying from monorepo root)
   - If your repo root is `sakura-erp-migration/`, set Root Directory to `frontend`
   - If your repo root is `sakura-erp-migration/frontend/`, leave Root Directory empty

---

## Step 3: Environment Variables

Add these in **Vercel → Project → Settings → Environment Variables**:

| Name | Value | Notes |
|------|-------|-------|
| `VITE_SUPABASE_URL` | `https://your-project.supabase.co` | Your Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | `eyJ...` | Your Supabase anon/public key |
| `VITE_API_URL` | (optional) | Backend API URL if using Express backend |

Get your Supabase credentials from [Supabase Dashboard](https://supabase.com/dashboard) → Project → Settings → API.

---

## Step 4: Deploy

1. Click **Deploy**
2. Vercel will run `npm run build` and output to `dist/`
3. Your app will be live at `https://your-project.vercel.app`

---

## Configuration (vercel.json)

The project includes `vercel.json` with:

- **Build**: `npm run build`
- **Output**: `dist/`
- **SPA rewrites**: All routes → `index.html` (except `/assets/*`)
- **Security headers**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection

---

## Troubleshooting

### Build fails
- Ensure Node.js 18+ (Vercel default)
- Check that `npm install` and `npm run build` work locally

### Blank page / 404
- Verify rewrites in `vercel.json` (SPA fallback to index.html)
- App uses hash routing (`/#/homeportal`) — no server config needed for routes

### Supabase connection fails
- Verify `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are set
- Ensure Supabase project has correct RLS policies for anon access

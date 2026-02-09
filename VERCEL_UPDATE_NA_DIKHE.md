# Repo update ho gaya lekin Vercel par nahi dikh raha

## Sabse pehle check karo: Root Directory

Vercel ko **frontend wala folder** build karna padta hai, repo root nahi.

1. **Vercel Dashboard** → apna project → **Settings** → **General**.
2. **Root Directory** dekho:
   - Agar **khali** hai ya `./` hai → galat. Isi wajah se push ke baad bhi purana build chal raha ho sakta hai.
   - Set karo:  
     `ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend`
3. **Save** karo.
4. **Deployments** tab → **Redeploy** (latest commit se).

## Agar Root Directory pehle se sahi hai

- **Deployments** → last deployment par jao → **Redeploy**.
- Ya naya commit push karo (e.g. `.\sync-to-git.ps1`) — Vercel auto-deploy karega.

## Batches: localStorage nahi

Batches ab **sirf Supabase** se aate hain (`grn_batches` table). localStorage fallback hata diya gaya hai — koi batch data localStorage me nahi rakha jata.

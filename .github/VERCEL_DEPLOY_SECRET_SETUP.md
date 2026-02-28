# Vercel auto-deploy: one-time secret setup

Is repo par **commit & push** se Vercel deploy trigger karne ke liye GitHub Actions use hota hai. Sirf **ek baar** ye secret add karo.

## Steps

1. **Vercel** → project **sakura-erp-system-miuq** → **Settings** → **Git** → **Deploy Hooks**
2. **Create Hook** (ya existing hook) → hook ka full URL copy karo  
   (jaise: `https://api.vercel.com/v1/integrations/deploy/prj_xxxx/yyyy`)
3. **GitHub** → repo **firoz-ali45/sakura-erp-system** → **Settings** → **Secrets and variables** → **Actions**
4. **New repository secret** → Name: `VERCEL_DEPLOY_HOOK_URL`, Value: jo URL copy kiya (step 2) → **Add secret**

Uske baad har **push to main** ya **push to fix/grn-batches** par GitHub Action chalegi aur Vercel deploy trigger ho jayega.

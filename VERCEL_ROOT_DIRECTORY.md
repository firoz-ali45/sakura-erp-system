# Vercel deploy fix – Root Directory (agar build phir bhi fail ho)

Agar **Git connected hai** lekin deployment **Error** dikh raha hai, to yeh try karo:

## Step 1: Vercel Dashboard mein Root Directory set karo

1. [Vercel](https://vercel.com) → project **sakura-erp-system-miuq** → **Settings**
2. **Build and Deployment** (left sidebar)
3. **Root Directory** section:
   - **Root Directory** field mein yeh path daalo (copy-paste):
   ```
   ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
   ```
   - **Save** karo

## Step 2: vercel.json simplify (optional)

Agar Root Directory set kar diya, to repo root wala `vercel.json` ka **outputDirectory** sirf `dist` ho sakta hai (kyunki ab build root yahi frontend folder hai). Abhi wala config bhi kaam karega.

## Step 3: Redeploy

- **Deployments** → latest failed deployment → **Redeploy**
- Ya koi bhi naya commit push karo, automatic deploy chalega

Iske baad build **Root Directory** se chalegi, isliye deploy stable rehna chahiye.

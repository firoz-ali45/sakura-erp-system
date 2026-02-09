# Vercel par Batches na dikhne ka fix

## Problem
Localhost par GRN detail me batches dikh rahe the, Vercel par same GRN me "No batches created yet".

## Cause
- Pehle code pehle `v_grn_all_batches` view se load karta tha. Agar ye view Supabase project me nahi bana tha to error aata aur fallback **localStorage** pe chala jata tha.
- Localhost par tumne batches create kiye the to woh isi browser ke localStorage me save ho gaye — isliye local par dikhe.
- Vercel par naya session → localStorage empty → batches empty dikhe.

## Code change (ho chuka)
`loadBatchesForGRN` ab pehle **`grn_batches`** table se load karta hai (jo hamesha exist karti hai), phir optional views. Isse local + Vercel dono same Supabase se batches laenge.

## Ab tum kya karo

1. **Commit + push**  
   ```powershell
   cd "C:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system"
   .\sync-to-git.ps1
   ```
2. **Supabase RLS**  
   Agar ab bhi Vercel par batches na dikhen to Supabase Dashboard → **Table Editor** → `grn_batches` → **RLS**. Ensure:
   - RLS enabled hai to **SELECT** ke liye policy ho (e.g. `anon` ya `authenticated` ko allow).
   - Ya RLS off ho to bhi chalega (dev ke liye).
3. **Vercel URL in Supabase** (optional)  
   Supabase → **Authentication** → **URL Configuration** → **Redirect URLs** me apna Vercel URL add karo, e.g. `https://sakura-erp-system-miuq.vercel.app/*`.

Iske baad same GRN Vercel par kholne par batches dikhne chahiye.

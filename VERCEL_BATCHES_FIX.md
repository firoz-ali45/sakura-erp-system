# Vercel par Batches na dikhne ka fix

## Problem
Localhost par GRN detail me batches dikh rahe the, Vercel par same GRN me "No batches created yet".

## Cause
- Pehle code pehle `v_grn_all_batches` view se load karta tha. Agar ye view nahi bana tha to fallback **localStorage** pe chala jata tha.
- Localhost par batches browser ke localStorage me the → dikhe. Vercel par localStorage empty → batches empty.

## Code change (ho chuka)
- **Batches ab sirf Supabase se** — localStorage fallback hata diya. `loadBatchesForGRN` pehle **`grn_batches`** table se load karta hai, phir optional views. Return empty agar kuch na mile.
- **localStorage batches kabhi use nahi** — na load, na getGRNByIdFromLocalStorage me. Yaad rakho: localStorage pe batches nahi rakhne.

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

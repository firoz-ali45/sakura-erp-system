# GRN Frontend Fix — Verification Steps

Agar commit/push ke baad bhi **koi change nahi dikh raha** (batch qty 0, remaining 0, common.notAvailable, created_by empty), to ye steps follow karein.

---

## 1. Confirm app is running from THIS folder

App **is folder se** run honi chahiye:

```
.../kmw/ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend
```

- **Dev:** Isi folder me `npm run dev` chalao (yahi Vite/Vue app hai).
- Agar app kisi **dusri location** se run ho rahi hai (e.g. parent repo, different clone), to wahan code update nahi hoga.

---

## 2. Restart dev server + hard refresh

- Terminal me dev server **band karo** (Ctrl+C) phir dubara:
  ```bash
  cd "ERP_Final - - Without_React2/ERP_Final - - Without_React/sakura-erp-migration/frontend"
  npm run dev
  ```
- Browser me **hard refresh**: `Ctrl+Shift+R` (Windows) ya `Cmd+Shift+R` (Mac).
- Zarurat ho to **cache clear** karo ya **Incognito** me open karo.

---

## 3. Browser console check (new code chal raha hai?)

1. GRN list se koi GRN open karo → **Batches** tab pe jao.
2. **F12** → **Console** tab kholo.
3. Ye line dikhni chahiye (matlab naya code chal raha hai):
   ```
   [GRN] Batches loaded (frontend-align): X first batch keys: ... qty_received/quantity: Y remaining_qty: Z
   [GRN] loadBatchesForGRNLocal: loaded X batches, createdByNameMap size: N
   ```

- **Agar ye lines NAHI dikhti:** App purana bundle use kar rahi hai (galat folder se run / cache). Step 1–2 dobara karo.
- **Agar dikhti hain but quantity/remaining ab bhi 0:** Database side check karo (Step 4).

---

## 4. Database check (Supabase)

Fix tabhi kaam karega jab:

- **grn_batches** = **VIEW** ho (table nahi), jo `batches` table se `qty_received AS quantity` expose karti ho.
- **v_batch_stock** view exist kare (for `remaining_qty`).
- **batches** table me `qty_received` column me actual values hon (0 nahi).

Supabase SQL Editor me run karo:

```sql
-- 1) grn_batches VIEW hai ya TABLE?
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'grn_batches';

-- 2) Sample batch row — quantity / qty_received kya aa raha hai?
SELECT id, grn_id, quantity, created_by, storage_location, vendor_batch_number
FROM grn_batches
LIMIT 3;

-- 3) v_batch_stock me remaining_qty?
SELECT batch_id, remaining_qty FROM v_batch_stock LIMIT 3;
```

- Agar `grn_batches` **BASE TABLE** hai (VIEW nahi), to frontend fix se batch quantity tab tak sahi nahi aayegi jab tak DB me **VIEW + triggers** wala architecture na ho.
- Agar `quantity` / `qty_received` rows me **0** hai, to data **batches** table me update karna padega (DB migration/backfill).

---

## 5. Summary

| Problem | Agar console me "[GRN] Batches loaded (frontend-align)" dikhe | Agar nahi dikhe |
|--------|---------------------------------------------------------------|------------------|
| Change dikhai nahi de raha | DB check karo (grn_batches VIEW, qty_received values) | App is folder se run karo, restart + hard refresh |

---

Console logs (Step 3) **temporary** hain — confirm ho jane ke baad hata sakte hain.

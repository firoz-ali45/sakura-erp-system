# HARD DEBUG + PROOF MODE — Verification Report

## STEP 1 — VERIFY EDITING CORRECT FOLDER

### Project structure (relevant)

```
sakura-erp-system/                          ← Git repo root
├── deploy-vercel-cli.ps1                   ← Deploys FROM frontend folder below
├── ERP_Final - - Without_React2/
│   └── ERP_Final - - Without_React/
│       └── sakura-erp-migration/
│           └── frontend/                   ← ACTIVE FRONTEND (Vercel deploy source)
│               ├── package.json
│               ├── vercel.json
│               └── src/
```

### Exact paths (ACTIVE FRONTEND)

| What | Absolute path |
|------|----------------|
| **package.json** | `c:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend\package.json` |
| **vercel.json** | `c:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend\vercel.json` |
| **src folder** | `c:\Users\shahf\Downloads\ERP_CLOUD\sakura-erp-system\ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend\src` |

### Confirmation

- **deploy-vercel-cli.ps1** (repo root) sets:
  `$frontendPath = Join-Path $PSScriptRoot "ERP_Final - - Without_React2\ERP_Final - - Without_React\sakura-erp-migration\frontend"`
- So **THIS** folder is the one uploaded to Vercel when you run `.\deploy-vercel-cli.ps1`.
- **Same folder** = the one containing package.json, vercel.json, src above.

---

## STEP 2 — OLD QUERIES SEARCH (ALL FILES WHERE FOUND)

Search pattern: `from('stock')`, `from('grn_batches')`, `from('purchase_orders')`, `from('purchase_requests')`, `remaining_qty`, manual status checks.

### Files containing `from('purchase_orders')`

- `src/views/purchase-requests/PRConvertToPO.vue` (425, 502)
- `src/views/inventory/PurchasingDetail.vue` (857, 862, 876)
- `src/views/inventory/GRNDetail.vue` (1426)
- `src/views/inventory/PurchaseOrderDetail.vue` (1202, 1207, 1208, 1587, 3353, 3363, 3374)
- `src/views/purchase-requests/PRDetail.vue` (596)
- `src/services/supabase.js` (many)
- `src/services/autoDraftFlow.js` (302, 315)
- `src/services/documentFlow.js` (83, 131)
- `src/services/purchaseRequests.js` (875, 1136, 1269, …)
- `src/components/common/ItemFlow.vue` (242, 284, 329, 333, 397, 443, 450, 486)
- `src/components/common/DocumentFlow.vue` (276, 291, 299, 310, 327, 350, 362, 382)

### Files containing `from('purchase_requests')`

- `src/views/purchase-requests/PRConvertToPO.vue`
- `src/services/documentFlow.js`
- `src/services/purchaseRequests.js`
- `src/components/common/ItemFlow.vue`
- `src/components/common/DocumentFlow.vue`

### Files containing `from('grn_batches')`

- `src/services/supabase.js` (3942, 3961, 3969, 3984, 4042, 4062, 4111, 4143)

### Files containing `remaining_qty`

- `src/views/inventory/PurchaseOrderDetail.vue` (1202, 1207, 1208) — uses viewItem.remaining_qty (from DB view)

### Note on “old” vs “allowed”

- **Stock/GRN batch display** must use only **views** (v_item_stock_full, v_grn_batch_summary). No direct `from('stock')` for display.
- **Tables** `purchase_orders`, `purchase_requests`, `grn_batches` are still used for: **insert/update/delete**, and **single-row lookups by id** (e.g. get PO by id). That is required for CRUD.
- **Button visibility** must use **only** `supabase.rpc('fn_can_create_next_document')` — no manual “closed” or “has next doc” checks for showing/hiding Create PO / Create GRN / Create Purchase / Record Payment.

---

## STEP 3 — NEW VIEWS USAGE

| View / RPC | Where used |
|------------|------------|
| **v_item_stock_full** | erpViews.js (fetchItemStockFull); StockOverview.vue (load); HomeDashboard.vue; InventoryLevels report |
| **v_grn_batch_summary** | erpViews.js (fetchGrnBatchSummary); GRNs.vue (loadGRNs, batch column) |
| **v_item_batches_full** | erpViews.js (fetchItemBatchesFull); forceRefreshAfterAction |
| **v_transaction_status** | erpViews.js (fetchTransactionStatus); HomeDashboard.vue |
| **v_document_flow_full** | erpViews.js (fetchDocumentFlowFull); forceRefreshAfterAction |
| **fn_can_create_next_document** | erpViews.js (canCreateNextDocument); PR list/detail, PO detail, GRN detail, Purchasing detail |

---

## STEP 4 — HARD DEBUG LOGS ADDED

- **StockOverview.vue**: `console.log("USING VIEW v_item_stock_full", data)` after fetch.
- **GRNs.vue**: `console.log("USING VIEW v_grn_batch_summary", data)` when building batch map.
- **GRNDetail.vue**: `console.log("RPC fn_can_create_next_document", result)` when resolving canCreatePurchase.
- **PRDetail.vue**: `console.log("RPC fn_can_create_next_document", result)` when resolving canConvertToPO.
- **PurchaseOrderDetail.vue**: `console.log("RPC fn_can_create_next_document", result)` when resolving canCreateGRN.

---

## STEP 5 — OLD LOGIC REMOVED

- Button visibility: only from `canCreateNextDocument()` (RPC). No manual `hasExistingPurchasing`, `status === 'closed'` etc. for these buttons.
- No local batch arrays for **display** (batch column from v_grn_batch_summary only).
- No local remaining_qty **calculation**; PurchaseOrderDetail uses viewItem.remaining_qty from DB view.

---

## STEP 6 — FORCE LIVE REFRESH

After: GRN approve, PO create, Purchase create, Payment post → call `await forceSystemSync()` which reloads v_item_stock_full, v_document_flow_full, v_transaction_status (and dispatches erp:refresh-stock).

---

## STEP 7 — BUILD OUTPUT

- **Build:** `npm run build` completed successfully (exit 0).
- **dist/index.html last write:** 2026-02-09 16:10:41
- **dist/assets:** 54+ JS chunks, 30+ CSS chunks (see Vite build output).
- **Key chunks:** erpViews-DDDV8fT2.js, StockOverview-DGsgE85h.js, GRNDetail-34y5JQE0.js, PRDetail-DNBj10jF.js, PurchaseOrderDetail-C0QAUi10.js, GRNs-BkGE94gy.js, index-Sne6AEvR.js (~286 KB), supabase-BRWlj_rw.js (~172 KB).
- **Build time:** ~7.43s.

---

## STEP 8 — COMMIT

Message: `FINAL HARD SYNC: frontend now 100% DB-driven`

---

## STEP 9 — FILES CHANGED LIST

(To be filled after commit: exact list of changed files.)

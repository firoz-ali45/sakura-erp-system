# Frontend–Supabase Sync (DB as Single Source of Truth)

All stock, batch, document flow, and button visibility come from Supabase. No local calculations or manual button logic.

## Views used (only these)

| Page / Feature | View / RPC | Notes |
|----------------|------------|--------|
| Stock Overview | `v_item_stock_full` | item_id, item_name, total_stock, batch_count, latest_batch, batch_numbers. Batch column: 1 batch → batch number; >1 → "N batches". Auto-refreshes on `erp:refresh-stock`. |
| Inventory Levels report | `v_item_stock_full` | Same source; batch display rule as above. |
| GRN grid batch column | `v_grn_batch_summary` | Join by grn_id; display `display_batch` ("3 batches" / batch_no / "-") |
| Dashboard (Home) | `v_transaction_status`, `v_item_stock_full` | Loads both views; totalTransactions from status count; warehouse outOfStockCount from item stock. |
| Button visibility | `fn_can_create_next_document(doc_type, doc_id)` | PR→Create PO; PO→Create GRN; GRN→Create Purchase; PURCHASE→Create Payment |

## Button visibility (RPC only)

- **PR list/detail:** "Convert to PO" → `fn_can_create_next_document('PR', pr_id)`
- **PO detail:** "Create GRN" → `fn_can_create_next_document('PO', po_id)`
- **GRN detail:** "Create Purchasing" → `fn_can_create_next_document('GRN', grn_id)`
- **Purchasing (invoice) detail:** "Record Payment" section → `fn_can_create_next_document('PURCHASE', purchase_id)`

Buttons are hidden when the RPC returns false (no manual status checks).

## Force refresh after actions

After each of these, the frontend calls `forceRefreshAfterAction()` (which refetches `v_transaction_status`, `v_document_flow_full`, `v_item_stock_full`, `v_item_batches_full` and dispatches `erp:refresh-stock`):

- PR create (save or create + submit)
- PO create (new PO from list modal; Convert to PO from PR)
- GRN approve
- Purchase (invoice) create from GRN
- Payment post (Record Payment)

No cached state for these; list/detail pages refetch as needed. Stock Overview listens for `erp:refresh-stock` and reloads when any action triggers a refresh.

## Test scenario (end-to-end)

1. Create PR with qty 10.
2. Convert to PO.
3. Receive GRN in 3 batches (create GRN, add 3 batches, approve).
4. Create Purchase (invoice) from GRN.
5. Record payment on the invoice.

**Expected:**

- Batch numbers correct (single batch number or "3 batches" where applicable).
- Stock overview correct from `v_item_stock_full`.
- Previous docs auto-closed (status from DB).
- "Create PO", "Create GRN", "Create Purchase", "Record Payment" hidden when next doc exists or chain closed.
- No duplicate chain; status correct everywhere.

## API service

- **`src/services/erpViews.js`** — `fetchItemStockFull`, `fetchGrnBatchSummary`, `canCreateNextDocument`, `fetchTransactionStatus`, `fetchDocumentFlowFull`, `fetchItemBatchesFull`, `forceRefreshAfterAction`.

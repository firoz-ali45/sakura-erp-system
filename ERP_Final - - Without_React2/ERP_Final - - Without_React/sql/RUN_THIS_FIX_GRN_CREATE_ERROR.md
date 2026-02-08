# Fix: Create GRN errors (document_flow)

**When:** Create GRN fails after approving a PO.

---

## Error 1: "column source_number of relation document_flow does not exist"

Run **`06_DOCUMENT_FLOW_ADD_COLUMNS.sql`** in Supabase SQL Editor (adds `source_number`, `target_number`, `flow_type`).

---

## Error 2: "null value in column source_id of relation document_flow violates not-null constraint"

**Root cause:** Frontend was setting `purchase_order_id` to null (wrong assumption that column is UUID). DB trigger then inserted `source_id = null`.  
**Fix applied in code:** Frontend now sends the numeric PO id (bigint).  
**Fix in DB (if you still see this):** Run **`07_DOCUMENT_FLOW_SOURCE_ID_NOT_NULL.sql`** in Supabase SQL Editor. It updates the trigger so `source_id` is derived from `purchase_order_number` when `purchase_order_id` is null (never insert null `source_id`).

---

## Order to run in Supabase SQL Editor

1. **06_DOCUMENT_FLOW_ADD_COLUMNS.sql** (if you had source_number error).
2. **07_DOCUMENT_FLOW_SOURCE_ID_NOT_NULL.sql** (for source_id not-null error).

Then retry **Create GRN** from the approved PO page.

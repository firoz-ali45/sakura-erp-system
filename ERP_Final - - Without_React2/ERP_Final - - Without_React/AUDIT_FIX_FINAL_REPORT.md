# CRITICAL BACKEND + DATA FLOW AUDIT — FINAL REPORT

## Executive Summary

Root causes were identified and fixes implemented for 4 critical ERP data integrity issues. Supabase MCP tools returned "Tool not found" during this session, so migrations were created as SQL files for you to run manually in Supabase SQL Editor.

---

## ISSUE 1 — Department in PR (Single Source of Truth)

### Root Cause
- **Department dropdown was hardcoded** in `PRCreate.vue` and `PRList.vue`
- `loadDepartmentsFromSupabase` was imported but **never called** — static array used instead
- No `departments` table existed

### Fixes Applied

**1. SQL Migration:** `sql/AUDIT_FIX_01_departments_table.sql`
- Creates `departments` table (id, code, name, is_active)
- Seeds default departments (Procurement, Kitchen, Warehouse, Operations, Administration, Finance, IT, Production, Quality Control, Sales)
- Adds `department_id` FK to `purchase_requests` (optional)
- Backfills `department_id` from existing `department` text column

**2. Frontend:**
- **supabase.js:** Added `loadDepartmentsFromSupabase()` — fetches from `departments` table
- **PRCreate.vue:** Replaced hardcoded `departments` with `loadDepartmentsFromSupabase()` in `loadInitialData`
- **PRList.vue:** Replaced hardcoded `departments` with `loadDepartmentsFromSupabase()` in `loadData`

### Verification
1. Run `sql/AUDIT_FIX_01_departments_table.sql` in Supabase SQL Editor
2. Create/Edit PR → Department dropdown should load from DB
3. Filter by Department in PR list → options from DB

---

## ISSUE 2 — Items & Suppliers Showing Only Few Records

### Root Cause
- **Item dropdown limited to 20:** `getFilteredItems()` used `filtered.slice(0, 20)` — capped visible suggestions
- **Suppliers localStorage key inconsistent:** `getSuppliersFromLocalStorage()` used `'suppliers'`; other modules use `'sakura_suppliers'`
- `loadItemsFromSupabase` and `loadSuppliersFromSupabase` did not filter `.eq('deleted', false)` at query level

### Fixes Applied

**1. Frontend:**
- **PRCreate.vue:** Removed `slice(0, 20)` from `getFilteredItems()` — now returns full filtered list
- **supabase.js:** 
  - `loadItemsFromSupabase`: Added `.eq('deleted', false)`
  - `loadSuppliersFromSupabase`: Added `.eq('deleted', false)`
  - `getSuppliersFromLocalStorage`: Fallback to both `'sakura_suppliers'` and `'suppliers'`

### Verification
1. PR Create → Item search should show all matching items (no 20-item cap)
2. PR Create / Convert PR→PO → Supplier dropdown should show full list
3. If Supabase fails, suppliers should load from correct localStorage key

---

## ISSUE 3 — Document Flow Showing Wrong Data (CRITICAL)

### Root Cause
- **pr_po_linkage backfill links by `item_id`** across ALL PRs and POs
- Same item (e.g., Glass Bottle sk-1074) used in PR-2026-00027 and PR-2026-000004
- Backfill linked PR-2026-00027's item to PO-000025 (which was created from PR-2026-000004)
- `v_item_transaction_flow` aggregated GRN qty by `item_id` → showed old PR's PO/GRN on new PR

### Fixes Applied

**1. SQL Migration:** `sql/AUDIT_FIX_03_document_flow_item_id.sql`
- Adds `source_pr_id` to `purchase_orders` (which PR created this PO)
- Adds `po_item_id` to `grn_inspection_items` (link GRN line to PO line)
- Adds `pr_item_id` to `purchase_order_items` (link PO line to PR line)
- Deletes incorrect `pr_po_linkage` rows where `pr_id != PO.source_pr_id` (when set)
- Recreates `v_item_transaction_flow` to:
  - Prefer `po_item_id` / `pr_item_id` for document chain
  - Fallback to `item_id` only when `po_item_id` / `pr_item_id` is NULL

### Required Frontend/Backend Flow Changes (Manual)
The Convert PR→PO flow **must**:
1. Set `purchase_orders.source_pr_id` = the PR being converted
2. Set `purchase_order_items.pr_item_id` = the PR item being converted
3. When creating GRN from PO, set `grn_inspection_items.po_item_id` = the PO item
4. Create `pr_po_linkage` during Convert PR→PO (not by item_id backfill)

### Verification
1. Run `sql/AUDIT_FIX_03_document_flow_item_id.sql` in Supabase
2. PR-2026-00027 detail → Item-wise flow should show only its own PO/GRN (or Pending if not converted)
3. Each PR must show only its own document chain

---

## ISSUE 4 — Stock Overview Batch "—" Showing

### Root Cause (From Previous Session)
- `grn_batches` was empty → trigger fell back to `grn_inspection_items` path
- Fallback path posted ledger with `batch_id = NULL`
- `v_inventory_balance` LEFT JOINs `inventory_batches` on `batch_id` → NULL `batch_number` → "—" in UI

### Fix Applied (Previous Session)
- Supabase migration `fix_stock_overview_batch_dash_permanent`:
  - Trigger fallback path now creates `inventory_batches` and uses `batch_id` (never NULL)
  - Backfilled existing ledger rows with NULL `batch_id`
- **Status:** Already applied and verified

---

## Migration Order

Run these in Supabase SQL Editor **in this order**:

1. `sql/AUDIT_FIX_01_departments_table.sql`
2. `sql/AUDIT_FIX_03_document_flow_item_id.sql`

(Stock Overview fix was already applied in previous session.)

---

## Summary of Files Changed

| File | Change |
|------|--------|
| `supabase.js` | Added `loadDepartmentsFromSupabase`, fixed suppliers localStorage key, added `.eq('deleted', false)` to items and suppliers |
| `PRCreate.vue` | Departments from DB, removed item slice(20) limit |
| `PRList.vue` | Departments from DB |
| `sql/AUDIT_FIX_01_departments_table.sql` | New — departments table + seed |
| `sql/AUDIT_FIX_03_document_flow_item_id.sql` | New — document chain columns + view fix |

---

## Confirmation

- Root causes identified from DB schema and frontend queries
- Migrations created for Supabase backend
- Frontend updated to use DB as single source of truth
- Document flow now uses `pr_item_id` / `po_item_id` when available
- System aligned with ERP document linkage architecture

**Note:** Supabase MCP tools returned "Tool not found" during this session. Run the SQL migrations manually in Supabase SQL Editor. After applying migrations and updating the Convert PR→PO flow to set `source_pr_id`, `pr_item_id`, and `po_item_id`, the document flow will be correct.

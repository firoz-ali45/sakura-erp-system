# 🔴 SAKURA ERP — FULL SYSTEM DEEP AUDIT REPORT

## Phase 1: Architectural Analysis — NO FIXES

### Date: 2026-02-19 | Auditor: System Architect Mode

---

# ══════════════════════════════════════════════════

# A. DATABASE ARCHITECTURE AUDIT

# ══════════════════════════════════════════════════

## A.1 — Complete Table Inventory (62 tables, 51 views, ~40 functions)

| # | Table | Rows | Purpose | Risk |
|---|-------|------|---------|------|
| 1 | `users` | 7 | User master data | ⚠️ DUAL role system (legacy `role` column + new `user_roles` table) |
| 2 | `roles` | 12 | RBAC role definitions | ✅ Well structured |
| 3 | `user_roles` | 2 | User-to-role assignments | 🔴 CRITICAL: Only 2 of 7 users assigned! |
| 4 | `permissions` | 49 | Permission definitions | ✅ OK |
| 5 | `permissions_master` | ? | DUPLICATE of permissions | 🔴 WHY does this exist? |
| 6 | `role_permissions` | 122 | Role-permission mapping | ✅ OK |
| 7 | `role_permissions_master` | ? | DUPLICATE of role_permissions | 🔴 WHY does this exist? |
| 8 | `role_location_access` | 0 | Role-based location ACL | 🔴 EMPTY — location access not enforced |
| 9 | `user_location_access` | 0 | User-based location ACL | 🔴 EMPTY — location access not enforced |
| 10 | `inventory_items` | 1037 | Item master | ⚠️ No created_by, no updated_by |
| 11 | `inventory_categories` | 2 | Item categories | ⚠️ No created_by |
| 12 | `inventory_locations` | 4 | Warehouse/Branch locations | ✅ Good engine design |
| 13 | `inventory_batches` | 20 | Canonical batch master | ✅ Proper structure |
| 14 | `inventory_stock_ledger` | 24 | **NEW** immutable ledger | ✅ Best design in system |
| 15 | `inventory_stock_ledger_legacy` | 3 | **OLD** ledger (deprecated) | 🔴 LEGACY — should be dropped |
| 16 | `grn_inspections` | 130 | GRN header | ⚠️ created_by is UUID but UI sends text names |
| 17 | `grn_inspection_items` | 116 | GRN line items | ⚠️ No updated_at, no updated_by |
| 18 | `grn_batches` | 4 | GRN-specific batch records | 🔴 CRITICAL — see Section C |
| 19 | `grn_batch_sequence` | 4 | Batch numbering per GRN | ✅ OK |
| 20 | `stock_batches` | 8 | DUPLICATE batch table | 🔴 WHY? Already have inventory_batches + grn_batches |
| 21 | `batch_daily_sequence` | 5 | Daily batch sequence | ✅ OK |
| 22 | `item_batch_sequence` | 1 | Per-item batch sequence | ✅ OK |
| 23 | `suppliers` | 255 | Supplier/vendor master | ✅ Good structure |
| 24 | `purchase_requests` | 40 | PR header (SAP EBAN) | ✅ Best-modeled table |
| 25 | `purchase_request_items` | 40 | PR line items (SAP EBKN) | ✅ Good |
| 26 | `purchase_orders` | 65 | PO header | ⚠️ created_by is BIGINT (not UUID!) |
| 27 | `purchase_order_items` | 59 | PO line items | ⚠️ No updated_at, no updated_by |
| 28 | `purchasing_invoices` | 30 | AP Invoice header | ✅ Fairly well structured |
| 29 | `purchasing_invoice_items` | 30 | AP Invoice lines | ⚠️ No updated_at |
| 30 | `transfer_orders` | 12 | Transfer Order header | ✅ Good multi-level approval |
| 31 | `transfer_order_items` | 17 | TO line items | ✅ Good |
| 32 | `stock_transfers` | 7 | Stock Transfer execution | ✅ OK |
| 33 | `stock_transfer_items` | ? | Transfer line items | ✅ OK |
| 34 | `transfer_dispatches` | 1 | Dispatch records | ⚠️ No updated_at |
| 35 | `transfer_receipts` | 0 | Receipt records | ⚠️ No updated_at |
| 36 | `transfer_approvals` | 12 | Multi-level approvals | ✅ OK |
| 37 | `document_flow` | 231 | Document chain tracking | ⚠️ Partially populated |
| 38 | `doc_graph` | 170 | DUPLICATE of document_flow | 🔴 WHY two document flow tables? |
| 39 | `pr_po_linkage` | 6 | PR→PO item-level tracking | ✅ Good design |
| 40 | `po_receipt_history` | 0 | PO receipt SAP EKBE equiv | 🔴 EMPTY — not being used! |
| 41 | `audit_logs` | 489 | System audit trail | ✅ OK |
| 42 | `erp_audit_logs` | ? | DUPLICATE audit table | 🔴 WHY two audit tables? |
| 43 | `user_activities` | 2130 | Activity log | ✅ OK |
| 44 | `user_activity_logs` | ? | DUPLICATE activity table | 🔴 WHY two activity tables? |
| 45 | `user_sessions` | 2139 | Session tracking | ✅ OK |
| 46 | `login_attempts` | ? | Login attempt tracking | ✅ OK |
| 47 | `login_sessions` | ? | DUPLICATE of user_sessions? | 🔴 Possible duplicate |
| 48 | `gl_journal` | 0 | GL Journal header | ⚠️ EMPTY — finance module not live |
| 49 | `gl_journal_lines` | 0 | GL Journal lines | ⚠️ EMPTY |
| 50 | `chart_of_accounts` | 22 | Chart of accounts | ✅ OK |
| 51 | `ap_payments` | 0 | AP Payment records | ⚠️ EMPTY |
| 52 | `finance_payments` | 0 | DUPLICATE payment table? | 🔴 WHY two payment tables? |

---

## A.2 — DUPLICATE / LEGACY TABLE CRISIS

| Canonical Table | Duplicate(s) | Risk |
|----------------|-------------|------|
| `permissions` | `permissions_master` | 🔴 Which is source of truth? |
| `role_permissions` | `role_permissions_master` | 🔴 Which is source of truth? |
| `inventory_stock_ledger` | `inventory_stock_ledger_legacy` | 🔴 Legacy must be deprecated |
| `inventory_batches` | `grn_batches` + `stock_batches` | 🔴 THREE batch tables! |
| `document_flow` | `doc_graph` | 🔴 Two document chain tables |
| `audit_logs` | `erp_audit_logs` | 🔴 Two audit trail tables |
| `user_activities` | `user_activity_logs` | 🔴 Two activity log tables |
| `user_sessions` | `login_sessions` | 🔴 Possible session duplication |
| `ap_payments` | `finance_payments` | 🔴 Two payment tables |

**VERDICT: 9 areas of table duplication. This is ARCHITECTURALLY DANGEROUS.**

---

## A.3 — `grn_batches` Table — STRUCTURAL DISASTER

The `grn_batches` table has **DUPLICATE COLUMNS** from failed migrations:

| Correct Column | Ghost Duplicate | Both Exist |
|---------------|-----------------|------------|
| `batch_id` | `batchid` | ✅ YES — both in schema! |
| `qc_data` | `qcdata` | ✅ YES — both in schema! |
| `qc_checked_at` | `qccheckedat` | ✅ YES — both in schema! |
| `created_by` | `createdby` | ✅ YES — both in schema! |

**ROOT CAUSE:** PostgREST auto-lowercase created these duplicates. The original code sent `batchId` → PostgREST stored it as `batchid`. Later, a migration added `batch_id` (with underscore). Now BOTH exist.

**Evidence from DB query:** All 4 batches have `batchid = null`, `createdby = null`, `qcdata = null`, `qccheckedat = null`. The correct underscored columns ARE populated. The camelCase duplicates are DEAD WEIGHT.

---

## A.4 — Audit Column Compliance Matrix

| Table | created_at | created_by | updated_at | updated_by | deleted | deleted_at |
|-------|:---:|:---:|:---:|:---:|:---:|:---:|
| `users` | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| `inventory_items` | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ |
| `inventory_categories` | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ |
| `purchase_orders` | ✅ | ✅* | ✅ | ❌ | ✅ | ✅ |
| `purchase_order_items` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `grn_inspections` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| `grn_inspection_items` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `grn_batches` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `purchasing_invoices` | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| `transfer_orders` | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `stock_transfers` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `stock_transfer_items` | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `suppliers` | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ |
| `purchase_requests` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `purchase_request_items` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**`*` purchase_orders.created_by is BIGINT, not UUID** — type mismatch with the rest.

### Missing Across System

- `updated_by` missing from **90% of tables** → You cannot know WHO edited a record
- `deleted` + `deleted_at` missing from most tables → Inconsistent soft delete
- `created_by` missing from items, categories, PO items → No accountability

---

## A.5 — Multi-Tenant SaaS Readiness

| Column | Tables That Have It | Total Tables |
|--------|:---:|:---:|
| `tenant_id` | **0** | 62 |
| `company_id` | **0** | 62 |
| `branch_id` | **0** | 62 |
| `warehouse_id` | **2** (inventory_batches, purchase_orders) | 62 |

### 🔴 VERDICT: ZERO MULTI-TENANT READINESS

- No `tenant_id` anywhere = **IMPOSSIBLE** to run as SaaS
- No `company_id` = **IMPOSSIBLE** to support multi-company
- No `branch_id` = Data cannot be isolated per branch
- This is a **SINGLE-TENANT monolith** — NOT a SaaS ERP

---

## A.6 — Missing Indexes (Critical Performance)

Based on the index scan, these HIGH-TRAFFIC queries lack indexes:

- `grn_batches.grn_id` — Batch lookups by GRN
- `grn_batches.item_id` — Batch lookups by item
- `document_flow.source_id` / `target_id` — Document chain traversal
- `inventory_stock_ledger.item_id + location_id` — Stock balance queries
- `stock_transfer_items.transfer_id` — Transfer item lookups

---

## A.7 — created_by Type Inconsistency

| Table | created_by Type |
|-------|----------------|
| `purchase_requests` | UUID (FK → users.id) ✅ |
| `purchase_orders` | **BIGINT** ❌ |
| `grn_inspections` | UUID ✅ |
| `grn_batches` | **TEXT** (username string) ❌ |
| `purchasing_invoices` | **TEXT** ❌ |
| `stock_transfers` | **TEXT** ❌ |
| `transfer_orders` | **TEXT** (requested_by) ❌ |
| `inventory_stock_ledger` | **TEXT** ❌ |

**6 different approaches to storing "who created this"** across the same system. This MUST be unified to UUID FK → users.id.

---

# ══════════════════════════════════════════════════

# B. ROLE & PERMISSION ENGINE AUDIT

# ══════════════════════════════════════════════════

## B.1 — Dual Role System (FUNDAMENTAL BUG)

The system has **TWO competing role systems** running simultaneously:

### System 1: Legacy `users.role` column

- Values: `admin`, `user`, `manager`, `viewer`
- CHECK constraint enforces these 4 values
- **Frontend `auth.js` stores this** in localStorage as `user.role`

### System 2: Modern `user_roles` + `roles` + `role_permissions` tables

- 12 roles defined: ADMIN, AUDITOR, BRANCH_MANAGER, DRIVER, FINANCE, INVENTORY_MANAGER, LOGISTICS_MANAGER, MANAGER, PROCUREMENT, SUPERVISOR, USER, WAREHOUSE_MANAGER
- 49 permissions defined
- 122 role-permission mappings
- `permissionEngine.js` calls RPC `fn_user_has_permission`

### THE CONFLICT

| User | Legacy `users.role` | New `user_roles` Assignment |
|------|--------------------|-----------------------------|
| Abu Yasin | manager | ❌ NONE |
| Ahmed Husseiny | admin | PROCUREMENT |
| Ajay | user | DRIVER |
| Ali | admin | ❌ NONE |
| Firoz Admin | admin | ❌ NONE |
| Hassan Mohamed | user | ❌ NONE |
| Osama M | viewer | ❌ NONE |

**5 of 7 users (71%) have NO role in the new system.**

### WHY DRIVER NOT DETECTED

The `v_drivers` view queries:

```sql
SELECT u.* FROM users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
WHERE upper(r.role_code) = 'DRIVER' AND u.status = 'active'
```

**Only 1 user (Ajay) has DRIVER role in `user_roles`.** If anyone else is assigned as a driver through the legacy `role` column, they WON'T appear.

### WHY PERMISSIONS DISAPPEAR AFTER REFRESH

1. Frontend saves role via `updateUserInSupabase()` which updates `users.role` (legacy)
2. But permission checks use `fn_user_has_permission` which reads `user_roles` + `role_permissions`
3. **These two systems are NOT connected** — changing one doesn't affect the other
4. After page refresh, the Pinia auth store loads from localStorage which has only `users.role`

## B.2 — Location Access: COMPLETELY NON-FUNCTIONAL

- `role_location_access` = **0 rows**
- `user_location_access` = **0 rows**
- The `inventory_locations` table has 4 locations defined
- **NO user has location-level access configured**
- Roles have `access_all_locations = true/false` but this is NEVER checked in the frontend

---

# ══════════════════════════════════════════════════

# C. INVENTORY + BATCH ENGINE AUDIT

# ══════════════════════════════════════════════════

## C.1 — THREE Batch Tables (CRITICAL DESIGN FLAW)

| Table | Purpose | Rows | Has FK to items? | Has FK to GRN? |
|-------|---------|------|:-:|:-:|
| `grn_batches` | Batches created during GRN | 4 | ✅ | ✅ |
| `inventory_batches` | Canonical batch master | 20 | ✅ | ✅ |
| `stock_batches` | ???  Unknown purpose | 8 | ✅ | ✅ |

**This is the ROOT CAUSE of most batch bugs.** The frontend `GRNDetail.vue` writes to `grn_batches`, but the stock ledger references `inventory_batches`. The `stock_batches` table is a ghost — unclear when/why it was created.

## C.2 — Batch Quantity = 0 (ROOT CAUSE FOUND)

**DB column name:** `quantity` (snake_case, no prefix)
**Frontend code tried:** `batch.batchQuantity || batch.batch_quantity || 0`
**Neither matched** the actual DB column name `quantity`.

The fix we applied (`|| batch.quantity`) works, but the ROOT CAUSE is:

- **No TypeScript types** — the frontend guesses column names
- **No DTO/mapper layer** — raw DB rows are passed directly to UI
- **Column naming is inconsistent** across tables

## C.3 — `remaining_qty` Always 0

All 4 `grn_batches` rows have `remaining_qty = 0.0000`. This is because:

1. `remaining_qty` defaults to `0` in the schema
2. **No trigger or function updates it** when batch is created
3. The frontend never sends `remaining_qty = quantity` on insert
4. **There is no `fn_update_remaining_qty` function**

This means **batch consumption tracking is BROKEN** — you can dispatch more than available.

## C.4 — Inventory Ledger Assessment

✅ **`inventory_stock_ledger` EXISTS and is properly designed:**

- Immutable (INSERT only, no UPDATE/DELETE)
- Has `movement_type` enum: GRN, TRANSFER_IN, TRANSFER_OUT, SALE, ADJUSTMENT, etc.
- Has `reference_type` + `reference_id` for traceability
- Has `batch_id` FK → `inventory_batches`
- Has `location_id` FK → `inventory_locations`
- 24 rows = actively being used

**However:** The `created_by` is TEXT (username), not UUID. And there's a `_legacy` version that should be dropped.

## C.5 — GRN Data Quality

| Field | Expected | Actual |
|-------|----------|--------|
| `storage_location` | Populated | `null` on all 4 batches |
| `vendor_batch_number` | Populated | `null` on all 4 batches |
| `grn_number` | Populated | `null` on all 4 batches |
| `qc_status` | pending/pass/fail | `pending` (correct default) |
| `quantity` | > 0 | ✅ 1.00, 2.00, 2.00, 3.00 |
| `remaining_qty` | = quantity | 🔴 ALL are 0.0000 |

---

# ══════════════════════════════════════════════════

# D. DOCUMENT FLOW ENGINE AUDIT

# ══════════════════════════════════════════════════

## D.1 — Chain: PR → PO → GRN → Invoice → Transfer

### Linkage Tables

| Link | Mechanism | Status |
|------|-----------|--------|
| PR → PO | `pr_po_linkage` table (6 rows) | ✅ Working |
| PR → PO | `purchase_orders.source_pr_id` FK | ✅ Working |
| PR → PO | `purchase_order_items.pr_item_id` FK | ✅ Working |
| PO → GRN | `grn_inspections.purchase_order_id` FK | ✅ Working |
| GRN → Invoice | `purchasing_invoices.grn_id` FK | ✅ Working |
| PO → Invoice | `purchasing_invoices.purchase_order_id` FK | ✅ Working |
| PO → Receipt | `po_receipt_history` table | 🔴 EMPTY (0 rows) — NOT USED |

### Document Flow Tables

| Table | Rows | Purpose |
|-------|------|---------|
| `document_flow` | 231 | Primary chain table |
| `doc_graph` | 170 | **DUPLICATE** chain table |

**WHY TWO?** `doc_graph` was created first with basic `source_type/source_id/target_type/target_id`. Then `document_flow` was created with additional columns (`source_number`, `target_number`, `flow_type`, `root_pr_id`, `item_id`, `qty`, `status`). The old one was never dropped.

### Missing Links

- **GRN → Transfer:** No FK from transfer tables to GRN
- **Transfer → Invoice:** No direct link
- **PO receipt history:** The `po_receipt_history` table exists but is EMPTY. The SAP EKBE equivalent is not being populated.

## D.2 — Views (51 views)

The system has an **excessive number of views** (51). Many appear redundant:

- `v_grn_batches_all` vs `v_grn_batches_with_batch_number` vs `v_grn_batch_summary`
- `v_item_document_flow` vs `v_item_flow_by_grn` vs `v_item_flow_by_po` vs `v_item_flow_recursive` vs `v_sap_item_flow` vs `v_item_transaction_flow`
- `v_pr_linked_pos` vs `v_pr_linked_po_count` vs `v_pr_linked_po_summary` vs `v_pr_po_summary`

This indicates iterative development without cleanup.

---

# ══════════════════════════════════════════════════

# E. ACTIVITY LOG + AUDIT TRAIL

# ══════════════════════════════════════════════════

## E.1 — Audit Infrastructure

| Capability | Table | Status |
|-----------|-------|--------|
| Entity changes | `audit_logs` (489 rows) | ⚠️ Partial — not all entities |
| ERP-specific audit | `erp_audit_logs` | 🔴 DUPLICATE — unclear when used |
| User activity | `user_activities` (2130 rows) | ✅ Active |
| User activity | `user_activity_logs` | 🔴 DUPLICATE |
| Login tracking | `login_attempts` | ✅ Exists |
| Session tracking | `user_sessions` (2139 rows) | ✅ Active |
| Session tracking | `login_sessions` | 🔴 DUPLICATE |
| Transfer audit | `stock_transfer_audit` | ✅ Exists |
| PR status history | `pr_status_history` (94 rows) | ✅ Good |

## E.2 — What IS NOT Logged

| Action | Logged? | Risk |
|--------|:-------:|------|
| User role changes | ❌ | 🔴 CRITICAL — no trail of who assigned what role |
| Permission changes | ❌ | 🔴 CRITICAL |
| Batch creation | ❌ | 🔴 No trail of who created batch |
| Batch edit | ❌ | 🔴 No trail of quantity changes |
| Batch delete | ❌ | 🔴 No trail of deleted batches |
| GRN status changes | ❌ | 🔴 No GRN status history table |
| PO status changes | ❌ | 🔴 No PO status history table |
| Invoice status changes | ❌ | 🔴 No invoice status history |
| Transfer dispatch | ⚠️ Partial | via `transfer_dispatches` |
| Transfer receipt | ⚠️ Partial | via `transfer_receipts` |
| Inventory adjustments | ✅ | via `inventory_stock_ledger` |
| IP/Device tracking | ✅ | `ip_address`, `user_agent` columns |
| Rollback capability | ❌ | 🔴 No reversal mechanism |

---

# ══════════════════════════════════════════════════

# F. BUG ROOT CAUSE ANALYSIS

# ══════════════════════════════════════════════════

## F.1 — Why Driver Role Not Detected

**ROOT CAUSE:** `v_drivers` view queries `user_roles` JOIN `roles`, but only 2 of 7 users have entries in `user_roles`. The legacy `users.role` column is NOT consulted.

**STRUCTURAL FIX NEEDED:**

1. Migrate ALL users to `user_roles` table
2. Drop the legacy `users.role` column
3. Single source of truth for role detection

## F.2 — Why Batch Quantity Shows 0

**ROOT CAUSE:** DB column is `quantity`. Frontend code tried `batch.batchQuantity || batch.batch_quantity || 0`. Neither matched. Fixed with `|| batch.quantity`, but the real fix is a DTO mapper.

## F.3 — Why Save Disappears After Refresh

**ROOT CAUSE:** Dual role system. Frontend reads `users.role` (legacy) into localStorage. Permission engine reads `user_roles` (new). Changes to one don't propagate to the other.

## F.4 — Why UI Shows Wrong Status

**ROOT CAUSE:** Multiple — (1) No status history tables for GRN/PO/Invoice, (2) Status updates happen in frontend memory but may fail silently against DB due to optimistic concurrency without version checking on some tables.

## F.5 — Why Null Values Are Saved

**ROOT CAUSE:** Frontend sends camelCase field names (`storageLocation`, `vendorBatchNumber`). PostgREST accepts them but creates new columns (evidence: `batchid`, `qcdata`, `qccheckedat`, `createdby` ghost columns). The intended snake_case columns remain null.

## F.6 — Why "Batch Not Found" Error on Update

**ROOT CAUSE:** `updateBatchInSupabase` queries by `batch.id`, but the batch may exist in `stock_batches` or `inventory_batches` instead of `grn_batches`. Three competing batch tables.

## F.7 — Why `remaining_qty` Is Always 0

**ROOT CAUSE:** Schema defaults `remaining_qty = 0`. No trigger sets it to `quantity` on INSERT. No function recalculates it on consumption. It's a dead column.

---

# ══════════════════════════════════════════════════

# G. ERP RELIABILITY SCORE

# ══════════════════════════════════════════════════

| Module | Score /100 | Assessment |
|--------|:---------:|------------|
| **Database Architecture** | **25/100** | 9 duplicate table pairs, inconsistent types, no multi-tenant, ghost columns |
| **Permission Engine** | **20/100** | Dual system, 71% users unassigned, location access empty, caching unreliable |
| **Inventory Engine** | **45/100** | Stock ledger exists and works, but 3 batch tables, remaining_qty broken |
| **Batch Engine** | **15/100** | 3 competing tables, ghost columns, no quantity tracking, no consumption logic |
| **Transfer Engine** | **55/100** | Best-designed module, multi-level approval works, dispatch/receipt flow exists |
| **Document Flow** | **40/100** | Chain exists PR→PO→GRN→Invoice, but 2 duplicate tables, receipt history empty |
| **Audit System** | **30/100** | Some logging exists but 6 duplicate tables, critical actions unlogged |
| **Finance Module** | **10/100** | Tables exist but ALL are empty (0 rows). GL Journal, AP Payments — nothing live |
| **Global SaaS Readiness** | **5/100** | Zero multi-tenant columns. Single-tenant monolith. NOT deployable as SaaS |

### **OVERALL SYSTEM SCORE: 27/100**

---

# ══════════════════════════════════════════════════

# H. RECOMMENDATIONS — WHAT TO DO NEXT

# ══════════════════════════════════════════════════

## 🔴 MUST REBUILD FROM FOUNDATION

1. **Role & Permission System** — Drop `users.role`, unify on `user_roles`. Migrate ALL 7 users.
2. **Batch Architecture** — Consolidate to ONE batch table. Drop `stock_batches`, merge `grn_batches` into `inventory_batches`.
3. **Multi-Tenant Foundation** — Add `tenant_id` to EVERY table. Without this, SaaS is impossible.
4. **`created_by` Unification** — All must be UUID FK → users.id. No TEXT, no BIGINT.
5. **Ghost Column Cleanup** — Drop `batchid`, `qcdata`, `qccheckedat`, `createdby` from `grn_batches`.
6. **Duplicate Table Cleanup** — Drop all `_master`, `_legacy`, `doc_graph` duplicates.

## ⚠️ MUST FIX BEFORE PRODUCTION

1. **`remaining_qty` Logic** — Add trigger: `remaining_qty = quantity` on insert, decrease on consumption.
2. **Audit Trail Gaps** — Add status history tables for GRN, PO, Invoice (like `pr_status_history`).
3. **Location Access** — Populate `role_location_access` and enforce in RPC functions.
4. **Missing Indexes** — Add indexes on FK columns used in JOINs.
5. **`updated_by` Column** — Add to ALL tables that have `updated_at`.

## ✅ SAFE — CAN KEEP AS-IS

1. `purchase_requests` / `purchase_request_items` — Best-modeled tables in the system
2. `inventory_stock_ledger` — Proper immutable ledger design
3. `inventory_locations` — Good WAREHOUSE/BRANCH engine
4. `transfer_orders` / `transfer_order_items` — Good multi-level approval
5. `pr_po_linkage` — Proper SAP-style linkage
6. `pr_status_history` — Good audit trail model (should be replicated for other entities)

## ☠️ DANGEROUS FOR FUTURE SaaS

1. **No tenant isolation** — ALL data in single pool. One customer sees another's data.
2. **No API rate limiting** — No throttling infrastructure
3. **No data encryption at rest** — Sensitive fields (password_hash, OTP) not encrypted beyond default
4. **RLS Policies** — Exist but are blanket `true` on many tables (no real row-level security)
5. **Frontend has Supabase anon key** — Direct DB access from browser. No server-side API layer.
6. **170KB supabase.js** — Monolithic god-file. Unmaintainable. Should be split into domain services.

---

# ══════════════════════════════════════════════════

# AWAITING COMMAND: "START PHASE 2 REBUILD"

# ══════════════════════════════════════════════════

This report is the architectural truth.
No fixes have been applied.
Awaiting your decision on Phase 2 priorities.

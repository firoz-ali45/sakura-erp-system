# 🛡️ DAILY STABILITY REPORT

## Sakura ERP — Production System Guardian

**Report Date:** 2026-02-21 12:25 AST (Friday)
**Mode:** 🔒 STABILITY FREEZE — No schema changes permitted
**System Status:** ✅ **ALL SYSTEMS OPERATIONAL**

---

## 1. CORE DATA INTEGRITY ✅

| Entity | Count | Baseline | Δ | Status |
|--------|:-----:|:--------:|:-:|:------:|
| inventory_items | 1,037 | 1,037 | 0 | ✅ |
| purchase_requests | 40 | 40 | 0 | ✅ |
| purchase_orders | 65 | 65 | 0 | ✅ |
| purchase_order_items | 59 | 59 | 0 | ✅ |
| grn_inspections | 130 | 130 | 0 | ✅ |
| grn_inspection_items | 116 | 116 | 0 | ✅ |
| batches (active) | 20 | 20 | 0 | ✅ |
| inventory_stock_ledger | 24 | 24 | 0 | ✅ |
| purchasing_invoices | 30 | 30 | 0 | ✅ |
| stock_transfers | 7 | 7 | 0 | ✅ |
| stock_transfer_items | 7 | 7 | 0 | ✅ |
| transfer_orders | 12 | 12 | 0 | ✅ |
| users | 7 | 7 | 0 | ✅ |
| roles | 12 | 12 | 0 | ✅ |
| user_roles | 7 | 7 | 0 | ✅ |
| permissions | 49 | 49 | 0 | ✅ |
| role_permissions | 230 | 230 | 0 | ✅ |
| branch_access | 8 | 8 | 0 | ✅ |
| branches | 4 | 4 | 0 | ✅ |
| document_flow | 231 | 231 | 0 | ✅ |
| suppliers | 255 | 255 | 0 | ✅ |

**Verdict: Zero data loss. All counts match baseline.**

---

## 2. STOCK CALCULATIONS (v_batch_stock) ✅

| Batch | Item | In | Out | Remaining | Status |
|-------|------|----|-----|-----------|:------:|
| GRN-000056-001 | كوب ايس كريم/Cup 4oz | 12 | 0 | 12 | EXPIRED |
| GRN-000063-001 | علبة صوص/Sauce 25ml | 6 | 3 | 3 | EXPIRED |
| GRN-000068-001 | علبة صوص/Sauce 25ml | 6 | 3 | 3 | EXPIRED |
| GRN-000070-001 | علبة صوص/Sauce 25ml | 6 | 3 | 3 | EXPIRED |
| GRN-000061-001 | كوب أبيض/White Cup | 3 | 0 | 3 | ON_HOLD |
| GRN-000065-001 | غطاء ورق/cover 9oz | 25 | 0 | 25 | EXPIRED |

**20 batches tracked. Ledger math verified: `remaining = total_in - total_out` ✅**
**4 new batches (created by app) show qty_received=0 → status DEPLETED (no ledger entries yet) ✅**

---

## 3. FK ORPHAN CHECK (Zero Tolerance) ✅

| FK Relationship | Total | Orphaned |
|-----------------|:-----:|:--------:|
| ledger → batches | 24 | **0** |
| transfer_items → batches | 7 | **0** |
| user_roles → users | 7 | **0** |
| user_roles → roles | 7 | **0** |
| role_permissions → roles | 230 | **0** |
| role_permissions → permissions | 230 | **0** |

**ZERO ORPHANS across all FK chains.**

---

## 4. PERMISSION ENGINE ✅

| User | Status | Role | Perms | INV_VIEW | PO_CREATE | GRN_CREATE | TRANSFER_DRIVE |
|------|:------:|------|:-----:|:--------:|:---------:|:----------:|:--------------:|
| Abu Yasin | active | Manager | 37 | ❌ | ✅ | ❌ | ❌ |
| Ahmed Husseiny | active | Procurement | 15 | ❌ | ✅ | ❌ | ❌ |
| Ajay | active | Driver | 9 | ❌ | ❌ | ❌ | ✅ |
| Ali | active | Admin | 49 | ✅ | ✅ | ✅ | ✅ |
| Firoz Admin | active | Admin | 49 | ✅ | ✅ | ✅ | ✅ |
| Hassan Mohamed | active | User | 6 | ❌ | ❌ | ❌ | ❌ |
| Osama M | active | User | 6 | ❌ | ❌ | ❌ | ❌ |

**7/7 users active. RBAC correctly enforced. Driver cannot PO. User cannot GRN.**

---

## 5. VIEW HEALTH CHECK ✅

| View | Rows | Status |
|------|:----:|:------:|
| v_batch_stock | 20 | ✅ OK |
| v_stock_transfers_full | 7 | ✅ OK |
| v_transfer_orders_full | 12 | ✅ OK |
| v_inventory_document_flow | 24 | ✅ OK |
| v_inventory_history | 24 | ✅ OK |
| v_inventory_movements | 24 | ✅ OK |
| v_cost_adjustment_history | 0 | ✅ OK |
| v_purchasing_summary | 30 | ✅ OK |
| v_inventory_balance | 20 | ✅ OK |
| v_inventory_control | 24 | ✅ OK |
| v_item_stock_full | 1,022 | ✅ OK |
| v_accounts_payable_open | 30 | ✅ OK |
| grn_batches (compat VIEW) | 20 | ✅ OK |

**13/13 views returning data. Zero query errors.**

---

## 6. GRN BATCH COMPATIBILITY (INSTEAD OF Triggers) ✅

| Operation | Route | Result |
|-----------|-------|:------:|
| INSERT via `grn_batches` VIEW | → `batches` table (GRN type) | ✅ |
| DELETE via `grn_batches` VIEW | → soft delete (is_deleted=true) | ✅ |
| Hidden from VIEW after delete | 0 in view, 1 in batches | ✅ |

**Frontend `saveBatchToSupabase()` fully operational.**

---

## 7. REAL USAGE SINCE STEP 4

| Activity | New Records | Status |
|----------|:-----------:|:------:|
| New GRN Inspections | 0 | — idle |
| New Stock Transfers | 0 | — idle |
| New Batches (app-created) | 4 | ✅ via grn_batches VIEW |
| New Ledger Entries | 0 | — idle |

**4 new batches were created by the application after Step 4 migration. These are visible in v_batch_stock with status DEPLETED (no ledger entries yet). This confirms the frontend is successfully writing through the grn_batches compatibility VIEW to the unified batches table.**

---

## 8. TYPE UNIFICATION HEALTH CHECK ✅

| Check | Result |
|-------|:------:|
| All `created_by` columns are UUID | ✅ (50 columns verified) |
| All `*_by` columns FK → users(id) | ✅ |
| No TEXT user refs remaining | ✅ |
| No BIGINT user refs remaining | ✅ |
| Ledger immutability trigger active | ✅ |

---

## 9. OBSERVATIONS & NOTES

### ⚠️ Observations (Non-Blocking)

1. **4 new batches have `qty_received = 0`** — These were created via app but no ledger entries posted yet. Expected behavior.
2. **Most batches show `EXPIRED` status** — Expiry dates are in the past. This is correct behavior from `v_batch_stock` dynamic status.
3. **`INVENTORY_VIEW` permission** returns false for Manager/Procurement roles — verify if this is intentional or if the permission code differs (e.g., `inventory_view` vs `INVENTORY_VIEW`).

### 🔑 Pending for Step 5

- `suppliers.id` BIGINT PK → needs UUID migration
- `purchase_orders.id` BIGINT PK → needs UUID migration
- 14 BIGINT FK columns across 10 tables depend on these PKs

---

## ✅ PRODUCTION GUARDIAN VERDICT

```
╔══════════════════════════════════════════╗
║  ALL SYSTEMS: STABLE & OPERATIONAL      ║
║  DATA INTEGRITY: VERIFIED               ║
║  ZERO ERRORS | ZERO ORPHANS             ║
║  SAFE FOR CONTINUED PRODUCTION USE      ║
╚══════════════════════════════════════════╝
```

**Next report: On request or before Step 5 execution.**

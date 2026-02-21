# 🔧 STEP 4 — TYPE UNIFICATION PLAN

## UUID Standardization for SaaS-Ready Architecture

---

## CATEGORY A: TEXT `created_by` → UUID (User Reference Columns)

**Strategy:** ADD new UUID column → backfill from users table → swap

| # | Table | Column | Current Type | Rows | Value | Risk |
|---|-------|--------|:------------:|:----:|-------|:----:|
| A1 | `stock_transfers` | `created_by` | TEXT | 7 | "Ali" | 🟢 |
| A2 | `inventory_stock_ledger` | `created_by` | TEXT | 24 | "Ali" | 🟡 |
| A3 | `inventory_stock_ledger` | `submitted_by` | TEXT | ? | "Ali" | 🟢 |
| A4 | `purchasing_invoices` | `created_by` | TEXT | 30 | "Ali" | 🟢 |
| A5 | `purchasing_invoices` | `approved_by` | TEXT | ? | ? | 🟢 |
| A6 | `purchasing_invoices` | `posted_by` | TEXT | ? | ? | 🟢 |
| A7 | `transfer_orders` | `requested_by` | TEXT | 12 | "Ali" | 🟢 |
| A8 | `transfer_orders` | `approved_by_level1` | TEXT | ? | ? | 🟢 |
| A9 | `transfer_orders` | `approved_by_level2` | TEXT | ? | ? | 🟢 |
| A10 | `transfer_orders` | `rejected_by` | TEXT | ? | ? | 🟢 |
| A11 | `transfer_dispatches` | `dispatched_by` | TEXT | 1 | "Ali" | 🟢 |
| A12 | `transfer_receipts` | `received_by` | TEXT | ? | ? | 🟢 |
| A13 | `transfer_approvals` | `approved_by` | TEXT | ? | ? | 🟢 |
| A14 | `transfer_damage_reports` | `created_by` | TEXT | ? | ? | 🟢 |
| A15 | `transfer_logistics_events` | `created_by` | TEXT | ? | ? | 🟢 |
| A16 | `transfer_quality_checks` | `checked_by` | TEXT | ? | ? | 🟢 |
| A17 | `stock_transfer_audit` | `performed_by` | TEXT | ? | ? | 🟡 |
| A18 | `gl_journal` | `created_by` | TEXT | ? | ? | 🟢 |
| A19 | `gl_journal` | `posted_by` | TEXT | ? | ? | 🟢 |
| A20 | `finance_payments` | `created_by` | TEXT | ? | ? | 🟢 |
| A21 | `ap_payments` | `created_by` | TEXT | ? | ? | 🟢 |
| A22 | `delivery_otp_logs` | `verified_by` | TEXT | ? | ? | 🟢 |
| A23 | `logistics_handover` | `handed_over_by` | TEXT | ? | ? | 🟢 |

**Mapping:** All "Ali" → `1500d040-69a0-47f1-b30b-4fa456d53836`

---

## CATEGORY B: BIGINT `created_by` → UUID

**Strategy:** ADD UUID column → migrate → drop BIGINT

| # | Table | Column | Current Type | Data | Risk |
|---|-------|--------|:------------:|:----:|:----:|
| B1 | `purchase_orders` | `created_by` | BIGINT | NULL (all) | 🟢 |

---

## CATEGORY C: TEXT `*_name` Denormalized Columns (Keep As-Is)

**Strategy:** These are display-name cache columns — NOT FK references. Keep for read performance.

| Table | Columns | Action |
|-------|---------|--------|
| `grn_inspections` | `received_by_name`, `approved_by_name`, `quality_checked_by_name`, `submitted_for_approval_by` | **KEEP** (display cache) |
| `pr_status_history` | `changed_by_name` | **KEEP** |
| `status_history` | `changed_by_name` | **KEEP** |

---

## CATEGORY D: BIGINT `supplier_id` / `purchase_order_id` (Document FKs)

**Strategy:** Keep BIGINT for now — suppliers/POs PK is BIGINT. Future Step 5 will unify these.

| # | Table | Column | Current Type | Action |
|---|-------|--------|:------------:|--------|
| D1 | `purchase_orders` | `supplier_id` | BIGINT | **KEEP** (FK to suppliers.id BIGINT PK) |
| D2 | `grn_inspections` | `supplier_id` | BIGINT | **KEEP** |
| D3 | `grn_inspections` | `purchase_order_id` | BIGINT | **KEEP** (FK to purchase_orders.id BIGINT PK) |
| D4 | `grn_inspection_items` | `purchase_order_id` | BIGINT | **KEEP** |
| D5 | `purchasing_invoices` | `supplier_id` | BIGINT | **KEEP** |
| D6 | `purchasing_invoices` | `purchase_order_id` | BIGINT | **KEEP** |
| D7 | `purchase_order_items` | `purchase_order_id` | BIGINT | **KEEP** |
| D8 | `po_receipt_history` | `purchase_order_id` | BIGINT | **KEEP** |
| D9 | `pr_po_linkage` | `po_id`, `po_item_id` | BIGINT | **KEEP** |
| D10 | `purchase_request_items` | `po_id`, `suggested_supplier_id` | BIGINT | **KEEP** |
| D11 | `finance_payments` | `vendor_id` | BIGINT | **KEEP** |
| D12 | `batches` | `supplier_id` | BIGINT | **KEEP** |

**Reason:** `suppliers.id` PK = BIGINT, `purchase_orders.id` PK = BIGINT.
Cannot change FK columns until PK tables are migrated (Step 5).

---

## CATEGORY E: TEXT IDs in Document/Audit Tables (Polymorphic — Keep As-Is)

**Strategy:** These store mixed document IDs as TEXT by design (polymorphic refs).

| Table | Column | Action |
|-------|--------|--------|
| `document_flow` | `source_id`, `target_id`, `source_document_id` | **KEEP** (polymorphic) |
| `doc_graph` | `source_id`, `target_id` | **KEEP** (polymorphic) |
| `audit_trail` | `entity_id` | **KEEP** (polymorphic) |
| `status_history` | `entity_id` | **KEEP** (polymorphic) |
| `idempotency_keys` | `entity_id` | **KEEP** (polymorphic) |

---

## CATEGORY F: ERP Schema Legacy (erp.grns)

**Strategy:** Legacy table — skip for now.

| Table | Column | Action |
|-------|--------|--------|
| `erp.grns` | `received_by`, `qc_checked_by` | **SKIP** (legacy erp schema) |

---

## EXECUTION PLAN

### Phase 1: TEXT → UUID User References (Category A)

Safe additive migration pattern per table:

1. `ALTER TABLE ADD COLUMN created_by_uuid UUID REFERENCES users(id);`
2. `UPDATE SET created_by_uuid = (SELECT id FROM users WHERE name = created_by);`
3. `ALTER TABLE DROP COLUMN created_by;`
4. `ALTER TABLE RENAME COLUMN created_by_uuid TO created_by;`

### Phase 2: BIGINT → UUID (Category B)

Same pattern for purchase_orders.created_by (all NULL, trivial).

### Phase 3: Verification

Cross-check all user references resolve correctly.

---

## RISK SUMMARY

| Category | Tables | Risk | Action |
|:--------:|:------:|:----:|--------|
| A | 23 columns in ~15 tables | 🟢 Low | EXECUTE NOW |
| B | 1 column in 1 table | 🟢 Low | EXECUTE NOW |
| C | 5 columns (display names) | — | KEEP AS-IS |
| D | 14 columns (BIGINT FKs) | 🔴 High | DEFER TO STEP 5 |
| E | 7 columns (polymorphic) | — | KEEP AS-IS |
| F | 2 columns (legacy) | — | SKIP |

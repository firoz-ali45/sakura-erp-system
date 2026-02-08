# SAP-Level ERP Corrections — Summary

All logic is in the **Supabase DB layer** (triggers, functions, views). No frontend hacks.

---

## PART 1 — GRN Batch Visibility

- **`item_batch_sequence`** — Global per-item sequence for batch numbers.
- **`fn_next_item_batch_number(item_id)`** — Returns `ITEMCODE-001`, `ITEMCODE-002`, … (from `inventory_items.sku`).
- **`stock_batches`** — One row per GRN batch: `id`, `item_id`, `grn_id`, `batch_no`, `expiry_date`, `qty_received`, `remaining_qty`, `created_at`.
- **Trigger** `trg_grn_batches_to_stock_batches` — On INSERT/UPDATE of `grn_batches`, syncs into `stock_batches` and assigns batch number if missing.
- **Views**
  - **`v_item_batches_full`** — Item → all batches with remaining qty.
  - **`v_grn_batch_summary`** — Per GRN: `batch_count`, `display_batch` (“3 batches” or single `batch_no`).
  - **`v_stock_overview_batches`** — Aggregated by item: `batch_count`, `total_remaining_qty`, `batch_numbers` array.

**Frontend:** GRN grid batch column → use `v_grn_batch_summary.display_batch`. Stock overview batch column → use `v_stock_overview_batches`.

---

## PART 2 — Auto Document Closing

Chain: **PR → PO → GRN → PURCHASE → PAYMENT.**

- When **PR** items have `quantity_remaining = 0` → PR `status = 'closed'`.
- When **PO** `remaining_quantity = 0` → PO `status = 'closed'`, `receiving_status = 'closed'`.
- When **Purchasing invoice** linked to GRN is fully paid → **GRN** `status = 'closed'`.
- When **Invoice** is fully paid → `status = 'posted'`, `payment_status = 'paid'`.

Triggers: `trg_pr_items_auto_close_pr`, `trg_po_after_update_close`, `trg_purchasing_invoice_auto_close_grn`, `trg_ap_payment_auto_close_invoice`.

---

## PART 3 — Button Visibility: `fn_can_create_next_document(doc_type, doc_id)`

Returns **true** only if the next document in the chain can be created (remaining qty > 0 or not closed).

- **PR** — `true` if any PR item has `quantity_remaining > 0`.
- **PO** — `true` if `remaining_quantity > 0`.
- **GRN** — `true` if GRN exists and `status <> 'closed'`.
- **PURCHASE / INVOICE** — `true` if invoice not fully paid.

**Frontend:** Call `SELECT fn_can_create_next_document('PR', $pr_id)` etc. and show/hide “Create PO”, “Create GRN”, “Create Purchase”, “Create Payment” based on result.

---

## PART 4 — Document Flow Table

- **New columns:** `root_pr_id`, `source_document_type`, `source_document_id`, `item_id`, `qty`, `status`.
- **Unique index:** `(source_type, source_id, target_type, target_id)` — no duplicate links.
- Duplicates were removed before adding the index.

---

## PART 5 — Status Engine

- **`fn_document_status_from_remaining(ordered, received, remaining)`** — Returns `Pending` | `Partial` | `Completed` | `Closed` (helper for UI/reports).
- **GRN** — `status` check constraint extended to include `'closed'`.
- PR/PO/GRN/Invoice status values used: `closed`, `posted`, `paid` as per existing DB constraints.

---

## PART 6 — Repair & Backfill

- **stock_batches** backfilled from existing `grn_batches` (with `fn_next_item_batch_number` where batch_number was empty).
- **document_flow** — `source_document_type` / `source_document_id` set from `source_type` / `source_id`.
- **PR/PO/Invoice** — One-time update to set `closed` / `posted` / `paid` where fully processed.

---

## PART 7 — Final Views

- **`v_document_flow_full`** — All document_flow columns (including new ones).
- **`v_item_stock_full`** — Item + total_stock (from ledger) + batch_count.
- **`v_batch_live_stock`** — Batches with `remaining_qty > 0` (from `stock_batches`).
- **`v_transaction_status`** — Union of PR, PO, GRN, PURCHASE with `doc_type`, `doc_id`, `doc_number`, `status`, `updated_at`.

---

## Migrations Applied (Supabase)

1. `sap_final_part1_grn_batch_visibility`
2. `sap_final_part2_auto_close_and_can_create`
3. `sap_final_part4_document_flow_columns`
4. `sap_final_part4_document_flow_unique_index` (after dedupe)
5. `sap_final_part5_status_engine`
6. `sap_final_status_values_fix` (closed/posted/paid + GRN constraint)
7. `sap_final_part6_repair_and_backfill`
8. `sap_final_part7_final_views`

---

## Frontend Checklist

- **GRN grid** — Batch column from `v_grn_batch_summary.display_batch`.
- **Stock overview** — Batch column from `v_stock_overview_batches` (batch_count, total_remaining_qty, batch_numbers).
- **Create PO / Create GRN / Create Purchase / Create Payment** — Visibility from `fn_can_create_next_document(doc_type, doc_id)`; hide when `false`.
- **Document status** — Use existing status + `closed` / `posted` / `paid`; no manual button logic.

All logic remains in Supabase; frontend only reads views and calls the function.

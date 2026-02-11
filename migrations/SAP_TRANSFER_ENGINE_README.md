# SAP Transfer Order Engine

Database-driven transfer order system with multi-warehouse, multi-level approval, ledger integration, and full audit trail.

## Tables

| Table | Purpose |
|-------|---------|
| `transfer_orders` | Header: from/to location, status, approval levels |
| `transfer_order_items` | Line items: requested/dispatched/received/variance qty |
| `transfer_approvals` | Approval audit: level, approved_by, approved_at |
| `transfer_dispatches` | Dispatch events: dispatched_by, dispatched_at |
| `transfer_receipts` | Receipt events: received_by, received_at |

## Status Flow

```
draft → submitted → level1_approved → level2_approved → [dispatched|partially_dispatched] → partially_received → closed
         ↓
      rejected
```

## RPCs (DB-Driven, No Frontend Logic)

### Approval
- `fn_submit_transfer(transfer_id)` — Submit draft for approval
- `fn_approve_transfer_level(transfer_id, level, approved_by)` — Approve at level 1 or 2
- `fn_reject_transfer(transfer_id, rejected_by)` — Reject transfer

### Execution
- `fn_dispatch_transfer(transfer_id, user_id)` — Dispatch: ledger TRANSFER_OUT, update items
- `fn_receive_transfer(transfer_id, user_id)` — Full receive: ledger TRANSFER_IN
- `fn_receive_transfer_item(transfer_id, item_id, qty, user_id)` — Partial receive per item

### Button Control (Frontend must call)
- `fn_can_dispatch_transfer(transfer_id)` — Returns true only if dispatch allowed
- `fn_can_receive_transfer(transfer_id)` — Returns true only if receive allowed

### Helper
- `fn_next_transfer_approval_step(transfer_id)` — Returns next_level, is_complete, can_dispatch

## Views

| View | Purpose |
|------|---------|
| `v_transfer_orders_full` | Full transfer with requested/dispatched/received/variance totals |
| `v_transfer_items_flow` | Item-level flow tracking |
| `v_transfer_variance` | All variance/shortfall tracking |

## Data Safety

- **No dispatch without approval** — Trigger blocks `transfer_dispatches` insert if status not level1/2_approved
- **No receive without dispatch** — Trigger blocks `transfer_receipts` insert if no dispatch record
- **Ledger immutable** — All stock moves via `inventory_stock_ledger` (TRANSFER_OUT, TRANSFER_IN)

## Document Flow

Chain: `TRANSFER_REQUEST` → `DISPATCH` → `RECEIPT` (inserted into `document_flow`)

## Migrations Applied

1. `sap_transfer_engine_part1_master_tables` — transfer_orders, transfer_order_items
2. `sap_transfer_engine_part2_approval_engine` — transfer_approvals, fn_next_transfer_approval_step
3. `sap_transfer_engine_part3_dispatch_engine` — transfer_dispatches, fn_dispatch_transfer
4. `sap_transfer_engine_add_partially_dispatched` — Enum value fix
5. `sap_transfer_engine_part4_receiving_engine` — transfer_receipts, fn_receive_transfer, fn_receive_transfer_item
6. `sap_transfer_engine_part5_auto_close` — Auto close when all items received
7. `sap_transfer_engine_part6_document_flow` — Document flow triggers
8. `sap_transfer_engine_part7_reporting_views` — v_transfer_orders_full, v_transfer_items_flow, v_transfer_variance
9. `sap_transfer_engine_part8_button_control_rpc` — fn_can_dispatch_transfer, fn_can_receive_transfer
10. `sap_transfer_engine_part9_data_safety` — Dispatch/receive guard triggers
11. `sap_transfer_engine_part10_performance` — Indexes for 100k+ scale
12. `sap_transfer_engine_approval_rpcs` — fn_submit_transfer, fn_approve_transfer_level, fn_reject_transfer

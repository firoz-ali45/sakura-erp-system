# SAP/FOODICS Inventory — Final Structure

## Database (migration: 20260209180000_sap_inventory_ledger_and_locations.sql)

### Location master (PART 2)
- **inventory_locations**: id, location_code, location_name, location_type (WAREHOUSE | BRANCH), allow_grn, allow_transfer_out, allow_pos_sale, allow_production, is_active
- **Rule**: PO/GRN destination = `WHERE is_active = true AND allow_grn = true`; Transfer OUT = allow_transfer_out; POS = allow_pos_sale; Production = allow_production; Reports = is_active = true

### Ledger (PART 3)
- **inventory_movement_type** (enum): GRN, TRANSFER_IN, TRANSFER_OUT, PRODUCTION_IN, PRODUCTION_CONSUMPTION, SALE_CONSUMPTION, RETURN_FROM_ORDER, RETURN_TO_SUPPLIER, WASTE, EXPIRY, ADJUSTMENT, COST_ADJUSTMENT, COUNT_VARIANCE (+ existing values if any)
- **inventory_stock_ledger**: id, item_id, location_id, batch_id, movement_type, qty_in, qty_out, unit_cost, total_cost, reference_type, reference_id, notes, reason, submitted_by, submitted_at, created_by, created_at
- **Rules**: qty_in OR qty_out only (never both); unit_cost mandatory; location_id mandatory; immutable (trigger `prevent_update_delete_ledger()` blocks UPDATE/DELETE)

### Views (PART 4 & 5)
| View | Purpose |
|------|--------|
| **v_inventory_balance** | item_name, sku, storage_unit, location_name, batch_no, current_qty, avg_cost, total_value — from ledger only |
| **v_inventory_history** | item_name, sku, barcode, location, transaction_type, reference, qty, cost, reason, notes, created_by, created_at — audit |
| **v_inventory_control** | Movement listing by date (filter in app). Use **fn_inventory_control_report(from_date, to_date)** for opening/in/out/closing report |
| **v_purchase_orders_report** | PO + location join |
| **v_transfer_orders_report** | Transfer orders + source/dest locations (or placeholder) |
| **v_transfers_report** | TRANSFER_IN/TRANSFER_OUT from ledger |
| **v_purchasing_report** | Invoices + location |
| **v_cost_adjustment_history** | ADJUSTMENT/COST_ADJUSTMENT/COUNT_VARIANCE/WASTE/EXPIRY from ledger |

## Frontend (PART 1, 6, 7)

### PART 1 — No ghost locations
- **useInventoryLocations.js**: All dropdowns load from `inventory_locations` only. GRN/PO = `is_active = true AND allow_grn = true` (no fallback to all locations). Transfer source = allow_transfer_out; destination = is_active; Production = allow_production; POS = allow_pos_sale; Reports = is_active.

### PART 6 — Sidebar & report pages
- **Sidebar**: Stock Overview, Inventory Levels, Inventory Control, Inventory History, Purchasing, Transfer Orders, Transfers, Cost Adjustment History (all under Inventory).
- **Report pages**: Read from views only (erpViews: fetchInventoryBalance, fetchInventoryHistory, fetchInventoryControlReport, fetchPurchasingReport, fetchTransferOrdersReport, fetchTransfersReport, fetchCostAdjustmentHistory). No direct table queries, no local calculations.

### PART 7 — Live sync
- After GRN approve, PO create, Purchase create, Payment post, Transfer, Production, Sale, Adjustment: **forceSystemSync()** reloads v_item_stock_full, v_document_flow_full, v_transaction_status, **v_inventory_balance**, **v_inventory_history** and dispatches `erp:refresh-stock` and `erp:refresh-inventory-views`. No cached state.

## Verification (PART 8)
- Run `migrations/VERIFICATION_SAP_INVENTORY.sql` after applying the migration.
- Test: Create warehouse → appears in dropdowns; GRN 100 qty → stock increases (ledger); Transfer → OUT + IN in ledger; Reports = ledger exactly; no ghost location; no negative stock (if enforced).

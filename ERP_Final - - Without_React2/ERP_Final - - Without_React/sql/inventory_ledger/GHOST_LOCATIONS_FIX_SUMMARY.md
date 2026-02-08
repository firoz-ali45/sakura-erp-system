# Ghost Locations Fix — Summary

## Done (Phase 1)

- **Single source of truth:** All location dropdowns now load from `inventory_locations` (Supabase). No hardcoded or cached lists.
- **Composable** `useInventoryLocations.js`:
  - `loadLocationsForGRN()` / `loadLocationsForPO()` → `allow_grn = true`
  - `loadLocationsForTransferSource()` → `allow_transfer_out = true`
  - `loadLocationsForTransferDestination()` → `is_active = true`
  - `loadLocationsForProduction()` → `allow_production = true`
  - `loadLocationsForPOS()` → `allow_pos_sale = true`
  - `loadLocationsForReports()` → `is_active = true`
- **GRNDetail.vue:** Receiving + storage location options = `[]` until loaded from API; no "Main Warehouse (W01)" default.
- **PurchaseOrders.vue:** Destination dropdown and filter use `destinationOptions` from `loadLocationsForPO()`; new order default destination = `''`.
- **PurchaseOrderDetail.vue:** Destination dropdown from `loadLocationsForPO()`; display fallback `—` instead of "Main Warehouse (W01)".
- **autoDraftFlow.js:** GRN draft no longer uses fallback `'Main Warehouse (W01)'`; uses PO destination or `''`.
- **PurchasingDetail.vue:** Display fallback for receiving_location set to `—`.

## Verification

1. In Supabase, run `sql/inventory_ledger/VERIFICATION_LOCATIONS_SINGLE_SOURCE.sql` and confirm rows match what you expect.
2. In app: create a Warehouse/Branch in **Manage → Inventory Locations**. It should appear in PO and GRN destination dropdowns (if `allow_grn` is true).
3. No locations should appear in dropdowns that are not in `inventory_locations` with `is_active = true`.

## Next (separate batches to avoid OOM)

- SQL: movement type ENUM extension, `v_inventory_history`, `v_inventory_control`, report views.
- Vue: Inventory Reports submenu, report pages (read-only from views).
- Transfer/Production/POS screens: wire destination/source dropdowns to the same composable (already implemented).

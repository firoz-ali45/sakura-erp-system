# Fix PO Received Quantities Issue

## Problem
PO items are not showing correct received quantities and remaining quantities after GRN approval. For example, if 12 items were ordered and 10 were received via GRN, the PO should show Received: 10, Remaining: 2, but it's not updating.

## Solution

### Step 1: Run the Database Fix Script

1. Open Supabase SQL Editor
2. Copy and paste the contents of `FIX_PO_ITEMS_RECEIVED_QUANTITIES.sql`
3. Run the script
4. This will:
   - Ensure `quantity_received` column exists in `purchase_order_items` table
   - Create function `update_po_item_received_quantities()` to update item-level quantities
   - Update the existing `update_po_received_quantities()` function to also update item-level quantities
   - Initialize existing PO item quantities

### Step 2: Verify the Fix

1. Run the verification script `VERIFY_PO_GRN_QUANTITIES.sql` in Supabase SQL Editor
2. This will help you:
   - Find POs with GRNs
   - Check PO items and their received quantities
   - Verify GRN items and their quantities
   - Check if triggers and functions are set up correctly
   - Manually trigger updates if needed

### Step 3: Test with Your PO

1. Find your PO ID (the one with 12 items ordered, 10 received)
2. In the verification script, replace `'YOUR_PO_ID_HERE'` with your actual PO ID
3. Run Step 7 to manually trigger the update: `SELECT update_po_received_quantities('YOUR_PO_ID_HERE');`
4. Check Step 4 to see if calculated quantities match database values

### Step 4: Refresh the Frontend

After running the database script:
1. Refresh your PO detail page in the browser
2. The received quantities should now be updated correctly
3. If not, check the browser console for any errors

## How It Works

1. **Database Triggers**: When a GRN is approved (status changes to 'passed'), database triggers automatically call `update_po_received_quantities()`
2. **Item-Level Update**: The function `update_po_item_received_quantities()` calculates received quantities for each PO item from approved GRNs
3. **PO-Level Update**: The function also updates PO-level totals (total_received_quantity, remaining_quantity)
4. **Frontend Display**: The frontend displays quantities from the database or calculates from GRNs (both should match)

## Important Notes

- GRN status must be 'passed', 'approved', or 'pending' for quantities to be counted
- GRN must have `deleted = false`
- GRN items must have correct `item_id` matching PO items' `item_id`
- If quantities still don't match, check if GRN items have the correct `item_id` set

## Troubleshooting

If quantities still don't update:

1. Check GRN status: Run `SELECT id, status, purchase_order_id FROM grn_inspections WHERE purchase_order_id = 'YOUR_PO_ID';`
2. Check GRN items: Run `SELECT item_id, received_quantity FROM grn_inspection_items WHERE grn_inspection_id = 'YOUR_GRN_ID';`
3. Check PO items: Run `SELECT item_id, quantity, quantity_received FROM purchase_order_items WHERE purchase_order_id = 'YOUR_PO_ID';`
4. Verify item_id matching: PO items and GRN items must have the same `item_id` for quantities to match
5. Manually trigger update: Run `SELECT update_po_received_quantities('YOUR_PO_ID');`

## Database Functions Created/Updated

- `update_po_item_received_quantities(po_id)` - Updates item-level received quantities
- `update_po_received_quantities(po_id)` - Updates both item-level and PO-level quantities (updated)


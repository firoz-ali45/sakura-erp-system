# PO Quantities Fix - Final Instructions

## Problem
PO me 12 items ordered the, 10 received via GRN (approved), but PO me Received: 10, Remaining: 2 nahi dikh raha.

## Solution

### Option 1: Complete Fix (Recommended - Ek Baar Run Karein)

1. **Supabase SQL Editor me jayein**
2. **File `FINAL_FIX_PO_QUANTITIES_COMPLETE.sql` open karein**
3. **Puri script copy karke run karein**
4. **Ye script:**
   - Functions create/update karega
   - Triggers recreate karega  
   - **Sabhi existing POs update kar dega automatically**
   - Future GRN approvals ke liye auto-update enable karega

### Option 2: Agar Specific PO Update Karna Ho

1. **File `UPDATE_SPECIFIC_PO_QUANTITY.sql` open karein**
2. **Line 5 me `40` ko apne PO ID se replace karein (e.g., 42, 43, etc.)**
3. **Sirf ye line run karein:**
   ```sql
   SELECT update_po_received_quantities(40);
   ```

### Verification

Apne PO ko verify karne ke liye ye query run karein (PO ID replace karein):

```sql
-- PO Level
SELECT 
    po.id,
    po.po_number,
    po.status,
    po.ordered_quantity,
    po.total_received_quantity,
    po.remaining_quantity
FROM purchase_orders po
WHERE po.id = 40;  -- Replace 40 with your PO ID

-- Item Level
SELECT 
    poi.id,
    poi.item_id,
    poi.quantity as ordered_qty,
    poi.quantity_received,
    (poi.quantity - poi.quantity_received) as remaining_qty,
    i.name as item_name
FROM purchase_order_items poi
LEFT JOIN inventory_items i ON i.id = poi.item_id
WHERE poi.purchase_order_id = 40  -- Replace 40 with your PO ID
ORDER BY poi.id;
```

### Important Points

1. ✅ **Ek baar `FINAL_FIX_PO_QUANTITIES_COMPLETE.sql` run karein - sab fix ho jayega**
2. ✅ **Triggers ab automatically kaam karenge - future GRN approvals par PO auto-update hoga**
3. ✅ **Database me data properly save hoga**
4. ✅ **Agar koi error aaye, mujhe bataiye**

### Agar Abhi Bhi Issue Ho

1. **Browser refresh karein** (Ctrl+F5)
2. **PO detail page refresh karein**
3. **Check karein ki GRN status 'passed' ya 'approved' hai**
4. **Check karein ki GRN items me correct `item_id` set hai**



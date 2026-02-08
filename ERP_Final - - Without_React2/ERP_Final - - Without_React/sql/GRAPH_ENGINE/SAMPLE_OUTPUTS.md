# SAP VBFA-Grade Recursive Document Graph Engine

## Sample JSON Outputs

### 1. From PR - Full Chain (PR → PO → GRN → PUR)

```sql
SELECT fn_get_document_flow_json('PR', 'your-pr-uuid-here');
```

**Expected Output:**
```json
{
  "pr": [
    {
      "id": "abc123-uuid",
      "number": "PR-2026-0001",
      "status": "fully_ordered",
      "date": "2026-01-15T10:00:00Z",
      "requester": "John Doe",
      "department": "Kitchen",
      "total_amount": 5000
    }
  ],
  "po": [
    {
      "id": 70,
      "number": "PO-2026-0070",
      "status": "approved",
      "date": "2026-01-16T14:00:00Z",
      "supplier": "ABC Supplier",
      "total_amount": 5000
    }
  ],
  "grn": [
    {
      "id": "def456-uuid",
      "number": "GRN-2026-0001",
      "status": "approved",
      "date": "2026-01-20T09:00:00Z",
      "received_by": "Jane Smith",
      "total_quantity": 25
    }
  ],
  "pur": [
    {
      "id": "ghi789-uuid",
      "number": "PUR-2026-0001",
      "status": "draft",
      "date": "2026-01-25T11:00:00Z",
      "payment_status": "unpaid",
      "grand_total": 5000
    }
  ],
  "start_type": "PR",
  "start_id": "abc123-uuid"
}
```

### 2. From PO - Trace Backwards and Forwards

```sql
SELECT fn_get_document_flow_json('PO', '70');
```

### 3. From GRN - Find All Connected Documents

```sql
SELECT fn_get_document_flow_json('GRN', 'grn-uuid-here');
```

### 4. From PUR - Trace Back to PR

```sql
SELECT fn_get_document_flow_json('PUR', 'pur-uuid-here');
```

---

## Item Flow View Output (EKBE Style)

```sql
SELECT * FROM v_item_flow_recursive WHERE pr_id = 'your-pr-uuid';
```

**Expected Output:**

| pr_item_id | pr_number | pr_pos | item_name | pr_qty | po_qty | grn_qty | pur_qty | remaining_po | chain_status |
|------------|-----------|--------|-----------|--------|--------|---------|---------|--------------|--------------|
| uuid-1 | PR-2026-0001 | 1 | Sauce bottle 25 ml | 25 | 25 | 25 | 25 | 0 | Invoiced |
| uuid-2 | PR-2026-0001 | 2 | Sugar 1kg | 100 | 100 | 80 | 0 | 20 | Partial Received |
| uuid-3 | PR-2026-0001 | 3 | Salt 500g | 50 | 0 | 0 | 0 | 0 | Pending |

---

## Status Logic

### Document Flow Status Colors:
- **Green (Exists)**: Document has been created
- **Yellow (Current)**: The document you're currently viewing
- **Gray (Not Created)**: Document doesn't exist yet in the chain

### Item Flow Status:
- **Pending**: `po_qty = 0` - No PO created yet
- **Ordered**: `po_qty > 0 AND grn_qty = 0` - PO exists, no GRN
- **Partial Received**: `grn_qty > 0 AND grn_qty < po_qty` - Partially received
- **Fully Received**: `grn_qty >= po_qty AND pur_qty = 0` - All received, not invoiced
- **Partial Invoiced**: `pur_qty > 0 AND pur_qty < grn_qty` - Partially invoiced
- **Invoiced**: `pur_qty >= grn_qty` - Fully invoiced

---

## Testing Commands

### Test the complete chain for your "Sauce bottle" item:

```sql
-- 1. Find the PR
SELECT id, pr_number, status FROM purchase_requests WHERE deleted = FALSE LIMIT 5;

-- 2. Get document flow
SELECT * FROM fn_get_document_flow('PR', 'paste-pr-uuid-here');

-- 3. Get JSON flow
SELECT fn_get_document_flow_json('PR', 'paste-pr-uuid-here');

-- 4. Get item flow
SELECT * FROM v_item_flow_recursive WHERE pr_id = 'paste-pr-uuid-here';

-- 5. Debug: Check linkages
SELECT 
    pr.pr_number,
    ppl.po_id,
    ppl.po_number,
    ppl.converted_quantity
FROM pr_po_linkage ppl
JOIN purchase_requests pr ON pr.id = ppl.pr_id
WHERE pr.deleted = FALSE
LIMIT 10;
```

---

## Troubleshooting

### If Document Flow Shows Empty:

1. Check if `pr_po_linkage` has records:
```sql
SELECT COUNT(*) FROM pr_po_linkage;
```

2. Check if `grn_inspections.purchase_order_id` is populated:
```sql
SELECT id, grn_number, purchase_order_id FROM grn_inspections WHERE deleted = FALSE LIMIT 10;
```

3. Check if `purchasing_invoices.grn_id` is populated:
```sql
SELECT id, purchasing_number, grn_id, purchase_order_id FROM purchasing_invoices WHERE deleted = FALSE LIMIT 10;
```

### If Quantities Don't Match:

1. Check `pr_po_linkage.converted_quantity`:
```sql
SELECT pr_item_id, SUM(converted_quantity) as total_ordered 
FROM pr_po_linkage 
GROUP BY pr_item_id;
```

2. Check `grn_inspection_items.received_quantity`:
```sql
SELECT gi.grn_number, gii.item_name, gii.received_quantity
FROM grn_inspection_items gii
JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
WHERE gi.deleted = FALSE;
```

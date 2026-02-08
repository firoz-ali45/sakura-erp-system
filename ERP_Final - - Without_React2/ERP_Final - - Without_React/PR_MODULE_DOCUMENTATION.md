# SAKURA ERP - Purchase Request (PR) Module Documentation

## Enterprise Architecture Following SAP MM Standards

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SAKURA ERP - PR MODULE ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   PRList    │    │  PRCreate   │    │  PRDetail   │    │ PRConvert   │  │
│  │    .vue     │───▶│    .vue     │───▶│    .vue     │───▶│  ToPO.vue   │  │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘  │
│         │                  │                  │                  │          │
│         └──────────────────┴──────────────────┴──────────────────┘          │
│                                    │                                        │
│                        ┌───────────▼───────────┐                           │
│                        │  purchaseRequests.js  │  Service Layer            │
│                        │    (Supabase API)     │                           │
│                        └───────────┬───────────┘                           │
│                                    │                                        │
├────────────────────────────────────┼────────────────────────────────────────┤
│                         POSTGRESQL │ / SUPABASE                            │
│                        ┌───────────▼───────────┐                           │
│                        │                       │                           │
│  ┌───────────────┐     │   BUSINESS LOGIC      │     ┌───────────────┐     │
│  │ purchase_     │     │   (Triggers/Functions)│     │ document_flow │     │
│  │ requests      │◀───▶│                       │◀───▶│               │     │
│  └───────┬───────┘     │  • PR Number Gen      │     └───────────────┘     │
│          │             │  • Status Workflow    │                           │
│  ┌───────▼───────┐     │  • PR→PO Conversion   │     ┌───────────────┐     │
│  │ purchase_     │     │  • Total Calc         │     │ pr_po_linkage │     │
│  │ request_items │◀───▶│  • RLS Policies       │◀───▶│               │     │
│  └───────────────┘     │                       │     └───────────────┘     │
│                        └───────────────────────┘                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Database Schema (SAP MM Equivalent)

### 2.1 Core Tables

| Sakura Table | SAP Equivalent | Purpose |
|-------------|----------------|---------|
| `purchase_requests` | EBAN | PR Header |
| `purchase_request_items` | EBAN/EBKN | PR Line Items + Account Assignment |
| `pr_number_sequence` | NRIV | Number Range for PR |
| `pr_status_history` | CDHDR/CDPOS | Change Documents |
| `pr_approval_workflow` | Release Strategy | Multi-level Approval |
| `pr_po_linkage` | EKPO-BANFN | PR to PO Item Mapping |
| `document_flow` | VBFA | Document Flow |

### 2.2 Entity Relationship

```
purchase_requests (1) ─────┬───── (N) purchase_request_items
                           │
                           ├───── (N) pr_status_history
                           │
                           ├───── (N) pr_approval_workflow
                           │
                           ├───── (N) pr_comments
                           │
                           └───── (N) pr_attachments

purchase_request_items (N) ────── (1) inventory_items
                           │
                           └───── (N) pr_po_linkage ───── (1) purchase_orders
```

---

## 3. Status Workflow (SAP Release Strategy)

```
┌─────────┐     ┌───────────┐     ┌──────────────┐     ┌──────────┐
│  DRAFT  │────▶│ SUBMITTED │────▶│ UNDER_REVIEW │────▶│ APPROVED │
└────┬────┘     └─────┬─────┘     └──────┬───────┘     └────┬─────┘
     │                │                   │                  │
     │                ▼                   ▼                  │
     │          ┌──────────┐       ┌──────────┐              │
     └─────────▶│ REJECTED │◀──────│ REJECTED │              │
                └──────────┘       └──────────┘              │
                                                             │
                      ┌──────────────────────────────────────┘
                      │
                      ▼
              ┌───────────────────┐     ┌──────────────┐     ┌────────┐
              │ PARTIALLY_ORDERED │────▶│ FULLY_ORDERED│────▶│ CLOSED │
              └───────────────────┘     └──────────────┘     └────────┘
```

### Status Definitions

| Status | Description | Editable | Can Convert |
|--------|-------------|----------|-------------|
| `draft` | Initial creation | Yes | No |
| `submitted` | Pending approval | No | No |
| `under_review` | Being reviewed | No | No |
| `approved` | Ready for PO | No | Yes |
| `rejected` | Approval denied | Reopen to draft | No |
| `partially_ordered` | Some items ordered | No | Yes (remaining) |
| `fully_ordered` | All items ordered | No | No |
| `closed` | Completed | No | No |

---

## 4. PR Number Generation

### Format: `PR-YYYY-NNNNNN`

Example: `PR-2026-000001`

### Implementation
- Atomic using `pg_advisory_xact_lock`
- Yearly reset (sequence per fiscal year)
- Prevents race conditions
- Admin override capability

```sql
-- Sequence Table
pr_number_sequence (fiscal_year, last_number)

-- Generation Function
generate_pr_number() → 'PR-2026-000042'
```

---

## 5. Document Flow (SAP VBFA Model)

```
                    PR-2026-000001
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    PO-2026-000001  PO-2026-000002  PO-2026-000003
          │              │              │
          ▼              ▼              ▼
    GRN-2026-000001 GRN-2026-000002 GRN-2026-000003
          │              │              │
          ▼              ▼              ▼
    INV-2026-000001 INV-2026-000002 INV-2026-000003
```

### Relationships Supported
- One PR → Multiple PO
- Multiple PR → One PO (Aggregation)
- Partial conversions

---

## 6. Business Rules (SAP Compliance)

### PR Does NOT:
- ❌ Affect inventory quantities
- ❌ Create finance postings
- ❌ Update stock ledger
- ❌ Create GL entries

### PR Only:
- ✅ Captures estimated requirements
- ✅ Tracks approval workflow
- ✅ Links to PO documents
- ✅ Provides planning data

### Actual Updates Happen At:
| Document | Inventory | Finance |
|----------|-----------|---------|
| PR | ❌ | ❌ |
| PO | ❌ | ❌ |
| GRN | ✅ Stock In | ❌ |
| Invoice | ❌ | ✅ AP Posting |

---

## 7. SQL Files Execution Order

Execute in this sequence:

```bash
1. PR_CORE_TABLES.sql          # Base tables
2. PR_NUMBER_TRIGGER.sql       # Number generation
3. PR_PO_LINKING.sql           # Document flow
4. PR_TO_PO_TRIGGER.sql        # Status workflow + conversion
5. PR_ANALYTICS_VIEWS.sql      # Reporting views
6. PR_INDEXES_AND_RLS.sql      # Performance + security
7. PR_MIGRATION_BACKFILL.sql   # Historical data (optional)
```

---

## 8. Vue Frontend Structure

```
src/
├── views/
│   └── purchase-requests/
│       ├── PRList.vue           # Main listing with KPIs
│       ├── PRCreate.vue         # Create/Edit form
│       ├── PRDetail.vue         # Detail view with timeline
│       └── PRConvertToPO.vue    # PO conversion wizard
│
├── services/
│   └── purchaseRequests.js      # Supabase API layer
│
├── router/
│   └── index.js                 # Routes added
│
└── config/
    └── sidebarConfig.js         # Menu item added
```

### Routes

| Route | Component | Description |
|-------|-----------|-------------|
| `/homeportal/pr` | PRList | PR listing |
| `/homeportal/pr-create` | PRCreate | Create new PR |
| `/homeportal/pr-create?edit={id}` | PRCreate | Edit existing PR |
| `/homeportal/pr-detail/{id}` | PRDetail | PR details |
| `/homeportal/pr-convert-to-po/{id}` | PRConvertToPO | Convert to PO |

---

## 9. API Functions (Supabase RPC)

### Workflow Functions

```javascript
// Submit PR for approval
submitPRForApproval(prId, notes)

// Approve PR
approvePurchaseRequest(prId, notes)

// Reject PR (reason required)
rejectPurchaseRequest(prId, reason)
```

### Conversion Functions

```javascript
// Convert PR(s) to PO
convertPRToPO(prIds[], supplierId, pricingMode, notes)
// pricingMode: 'estimated' | 'last_po' | 'inventory_cost' | 'manual'

// Convert single item
convertSinglePRItemToPO(itemId, poId, supplierId, quantity, price)
```

### Analytics Functions

```javascript
// Dashboard statistics
getPRDashboardStats(department, startDate, endDate)

// Trend data for charts
getPRTrendData(months, department)

// Document flow tree
getPRDocumentFlow(prId)
```

---

## 10. Sample API Calls (Supabase JS)

### Create Purchase Request

```javascript
import { createPurchaseRequest } from '@/services/purchaseRequests';

const result = await createPurchaseRequest({
  requesterId: 'user-uuid',
  requesterName: 'John Doe',
  department: 'Kitchen',
  costCenter: 'CC001',
  priority: 'high',
  requiredDate: '2026-02-15',
  notes: 'Urgent requirement',
  items: [
    {
      itemId: 'item-uuid',
      itemName: 'Flour',
      quantity: 100,
      unit: 'KG',
      estimatedPrice: 5.50,
      suggestedSupplierId: 123
    }
  ]
});
```

### Convert PR to PO

```javascript
import { convertPRToPO } from '@/services/purchaseRequests';

const result = await convertPRToPO(
  ['pr-uuid-1', 'pr-uuid-2'], // Multiple PRs
  123,                         // Supplier ID
  'last_po',                   // Pricing mode
  'Combined order'             // Notes
);

// Result
{
  success: true,
  po_id: 456,
  po_number: 'PO-2026-000042',
  supplier_name: 'ABC Supplies',
  total_amount: 5500.00,
  items_converted: 5,
  prs_processed: 2
}
```

### Get Dashboard Stats

```javascript
import { getPRDashboardStats } from '@/services/purchaseRequests';

const stats = await getPRDashboardStats('Kitchen', '2026-01-01', '2026-01-31');

// Result
{
  total_prs: 45,
  draft_count: 5,
  pending_approval: 8,
  approved_count: 12,
  partially_ordered: 3,
  fully_ordered: 10,
  closed_count: 5,
  rejected_count: 2,
  total_value: 125000.00,
  overdue_count: 3,
  high_priority_count: 7
}
```

---

## 11. Testing Checklist

### Database Tests

- [ ] PR number generates correctly (format PR-YYYY-NNNNNN)
- [ ] PR number is unique and atomic
- [ ] PR number resets yearly
- [ ] Status transitions enforce workflow rules
- [ ] Invalid transitions are blocked
- [ ] Items total updates header automatically
- [ ] RLS policies work correctly for different roles

### Workflow Tests

- [ ] Draft PR can be edited
- [ ] Submitted PR cannot be edited
- [ ] Only approvers can approve/reject
- [ ] Rejection requires reason
- [ ] Approved PR can be converted to PO
- [ ] Partial conversion updates status correctly
- [ ] Full conversion closes PR

### Conversion Tests

- [ ] Single PR converts to PO correctly
- [ ] Multiple PRs aggregate into one PO
- [ ] PR items lock after conversion
- [ ] Document flow records created
- [ ] pr_po_linkage records created
- [ ] Quantity tracking is accurate
- [ ] Price variance calculated correctly

### Frontend Tests

- [ ] PRList displays KPIs correctly
- [ ] Filters work (status, department, date)
- [ ] Search works (PR number, requester)
- [ ] PRCreate validates required fields
- [ ] Item picker searches inventory
- [ ] PRDetail shows status timeline
- [ ] Document flow visualization works
- [ ] Convert to PO wizard completes

### Security Tests

- [ ] Users see only their own PRs
- [ ] Managers see department PRs
- [ ] Procurement sees all PRs
- [ ] Only draft PRs can be deleted
- [ ] Locked items cannot be modified

---

## 12. Performance Considerations

### Indexes Created

- `idx_pr_number` - PR number lookup
- `idx_pr_status` - Status filtering
- `idx_pr_department` - Department filtering
- `idx_pr_requester_id` - User's PRs
- `idx_pr_status_department` - Combined filters
- `idx_pri_pr_id` - Items by PR
- `idx_pri_status` - Item status

### Query Optimization

- Views pre-aggregate common data
- Partial indexes for common filters
- ANALYZE run after table creation

---

## 13. Troubleshooting

### Common Issues

**PR Number Collision**
```sql
-- Check sequence
SELECT * FROM pr_number_sequence;
-- Reset if needed (admin only)
SELECT reset_pr_sequence_for_year(2026, 0);
```

**Status Transition Blocked**
```sql
-- Check valid transitions
SELECT * FROM pr_status_transitions
WHERE from_status = 'current_status';
```

**Conversion Failed**
```sql
-- Check PR status
SELECT id, status FROM purchase_requests WHERE id = 'uuid';
-- Must be 'approved' or 'partially_ordered'
```

---

## 14. Future Enhancements

- [ ] Email notifications on status change
- [ ] Budget check integration
- [ ] Automatic approval for low-value PRs
- [ ] Mobile-responsive PR creation
- [ ] Batch PR upload from Excel
- [ ] Integration with external catalogs

---

**Document Version:** 1.0.0  
**Last Updated:** January 25, 2026  
**Author:** Enterprise ERP Team

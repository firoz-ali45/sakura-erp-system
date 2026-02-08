# Auto-Draft Flow Implementation
## PO → GRN → Purchasing Business Logic

**Status:** ✅ Implemented  
**ISO 22000 / FSSC 22000 Compliant**  
**Date:** 2025-12-21

---

## 📋 Overview

This document describes the implementation of the correct business logic and auto-draft flow between Purchase Order → GRN → Purchasing modules in Sakura ERP.

---

## 🎯 Core Business Rules (LOCKED)

These rules are **non-negotiable** and form the foundation of the system:

1. **One Purchase Order → Multiple GRNs (Allowed)**
   - A single PO can have multiple deliveries
   - Each delivery creates a separate GRN
   - Allows partial deliveries and multiple receiving dates

2. **One GRN → One Purchasing (Not allowed to split)**
   - A single GRN cannot be split into multiple Purchasing records
   - Ensures accounting integrity

3. **Multiple GRNs → One Purchasing (Allowed)**
   - Multiple approved GRNs can be merged into one Purchasing
   - Useful for consolidating invoices from same supplier

4. **Purchasing can be created ONLY from Approved GRN(s)**
   - Rejected or partial GRNs are blocked
   - Ensures only quality-approved goods enter accounting

5. **GRN can exist with or without PO (Direct / Market Purchase)**
   - Supports market purchases without prior PO
   - Direct GRNs also flow into Purchasing when approved

---

## 🔄 PART 2: PO → GRN AUTO-DRAFT LOGIC

### Implementation

**File:** `sakura-erp-migration/frontend/src/services/autoDraftFlow.js`

**Function:** `createGRNDraftFromPO(purchaseOrder)`

**Trigger:** When PO status changes to `approved`

### Auto-Draft Process

1. **Validation:**
   - PO must be in `approved` status
   - Check if GRN draft already exists (prevents duplicates)

2. **Data Mapping:**
   - **Supplier:** Auto-filled from PO supplier
   - **PO Reference:** Linked to approved PO
   - **Items:** All PO items mapped to GRN items
   - **Ordered Quantity:** From PO items
   - **Received Quantity:** Defaults to ordered qty (editable)
   - **Unit of Measure:** From PO items
   - **Receiving Location:** Defaults from PO destination
   - **External Reference ID:** From PO (Foodics integration)

3. **GRN Status:**
   - Always created as `draft`
   - **NOT auto-approved**
   - **NOT auto-creates batches**
   - Fully editable by warehouse user

4. **GRN Number:**
   - Generated only on "Submit For Inspection"
   - Empty string in draft status

### Integration Point

**File:** `sakura-erp-migration/frontend/src/views/inventory/PurchaseOrderDetail.vue`

**Function:** `approveOrder()`

**Hook:** `onPOApproved(purchaseOrder)`

When PO is approved:
```javascript
const { onPOApproved } = await import('@/services/autoDraftFlow');
const grnResult = await onPOApproved(result.data);
```

### PO Status Logic

**Function:** `updatePOStatusBasedOnGRNs(poId)`

PO status updates based on GRN status:
- **Approved + No GRN** → `approved`
- **Approved + Partial GRN** → `partially_received`
- **Approved + Full GRN(s)** → `fully_received`

---

## 🔄 PART 3: GRN → PURCHASING AUTO-DRAFT LOGIC

### Implementation

**File:** `sakura-erp-migration/frontend/src/services/autoDraftFlow.js`

**Function:** `preparePurchasingDraftFromGRN(grn)`

**Trigger:** When GRN status changes to `approved`

### Purchasing Draft Payload Structure

**IMPORTANT:** This creates a **data payload**, NOT an actual Purchasing record. The Purchasing UI module is not built yet.

```javascript
{
  // Source Information
  source: 'po_grn' | 'direct_grn',
  grnId: string,
  grnNumber: string,
  grnDate: string,
  
  // PO Reference (if exists)
  purchaseOrderId: string | null,
  purchaseOrderReference: string | null,
  
  // Supplier Information
  supplier: string,
  supplierId: string,
  
  // Financial Fields (blank, editable later)
  invoiceAmount: null,
  invoiceNumber: '',
  taxAmount: null,
  taxRate: null,
  totalAmount: null,
  
  // Purchasing Status
  status: 'draft',
  
  // Approved Quantities from GRN
  items: [
    {
      itemId: string,
      item: object,
      approvedQuantity: number,
      batchIds: string[]
    }
  ],
  
  // Batch Details
  batches: [
    {
      batchId: string,
      batchNumber: string,
      itemId: string,
      quantity: number,
      expiryDate: string,
      storageLocation: string
    }
  ],
  
  // Metadata
  receivingLocation: string,
  receivedBy: string,
  qcCheckedBy: string,
  
  // ISO 22000 Flags
  isDraftPayload: true,
  readyForPurchasingCreation: true
}
```

### Integration Point

**File:** `sakura-erp-migration/frontend/src/views/inventory/GRNDetail.vue`

**Function:** `approveGRN()`

**Hook:** `onGRNApproved(grn)`

When GRN is approved:
```javascript
const { onGRNApproved } = await import('@/services/autoDraftFlow');
const purchasingResult = await onGRNApproved(result.data);
```

### Storage

Purchasing Draft Payloads are stored in:
- **localStorage:** `sakura_purchasing_draft_payloads` (temporary)
- **Future:** Will be moved to database when Purchasing module is built

### Merging Multiple GRNs

**Function:** `mergePurchasingDraftPayloads(grnIds)`

Allows merging multiple approved GRNs into one Purchasing:
- Validates all GRNs are approved
- Merges items and batches
- Creates unified Purchasing Draft Payload

---

## 🔄 PART 4: DIRECT / MARKET PURCHASE FLOW

### Implementation

**Function:** `preparePurchasingDraftFromDirectGRN(grn)`

Direct GRNs (without PO) follow the same flow:
- GRN Type: `Direct / Market Purchase`
- Supplier: Mandatory
- PO Reference: `null`
- When approved: Prepares Purchasing Draft Payload
- Source: Marked as `direct_grn`

---

## 📊 Data Model Relationships

### PurchaseOrder
```javascript
{
  id: string,
  poNumber: string,
  status: 'pending' | 'approved' | 'partially_received' | 'fully_received',
  // ... other fields
  // hasMany GRNs (via purchaseOrderId)
}
```

### GRN
```javascript
{
  id: string,
  grnNumber: string,
  status: 'draft' | 'under_inspection' | 'approved' | 'rejected',
  purchaseOrderId: string | null, // belongsTo PurchaseOrder (nullable)
  // ... other fields
  // hasOne Purchasing (future, via purchasingId)
}
```

### Purchasing (Future)
```javascript
{
  id: string,
  status: 'draft' | 'approved',
  grnIds: string[], // hasMany GRNs
  // ... other fields
}
```

---

## 🔧 Technical Implementation

### Service File

**Location:** `sakura-erp-migration/frontend/src/services/autoDraftFlow.js`

### Key Functions

1. **PO → GRN Flow:**
   - `createGRNDraftFromPO(purchaseOrder)`
   - `updatePOStatusBasedOnGRNs(poId)`
   - `onPOApproved(purchaseOrder)`

2. **GRN → Purchasing Flow:**
   - `preparePurchasingDraftFromGRN(grn)`
   - `preparePurchasingDraftFromDirectGRN(grn)`
   - `getPurchasingDraftPayloads()`
   - `mergePurchasingDraftPayloads(grnIds)`
   - `onGRNApproved(grn)`
   - `onGRNStatusChanged(grn)`

### Event-Driven Architecture

- **Hooks:** Triggered on status changes
- **Watchers:** Can be added to watch status changes
- **Services:** Clean separation of business logic

---

## ✅ Validation Rules

### PO → GRN
- ✅ PO must be `approved`
- ✅ Prevents duplicate GRN drafts
- ✅ GRN remains editable
- ✅ GRN does NOT auto-approve

### GRN → Purchasing
- ✅ GRN must be `approved`
- ✅ Rejected GRNs are blocked
- ✅ Only approved batches included
- ✅ Multiple GRNs can be merged

---

## 🎨 UI Behavior

### PO Screen
- **Button:** "Approve PO"
- **On Approval:** 
  - PO status → `approved`
  - GRN Draft auto-created
  - Notification shown
- **Button:** "View GRNs" (future - link to GRNs filtered by PO)

### GRN Screen
- **Status:** Driven by QC & batches
- **On Approval:**
  - GRN status → `approved`
  - Purchasing Draft Payload prepared
  - PO status updated (if linked)
  - Stock posted at batch level

### Purchasing Screen
- **Status:** NOT visible yet (module not built)
- **Data:** Payloads stored and ready
- **Future:** Will consume draft payloads to create Purchasing records

---

## 📝 ISO 22000 Compliance Notes

### Separation of Concerns
- **Commercial Data (PO):** Purchase commitment
- **Physical Data (GRN):** Actual receipt with QC
- **Accounting Data (Purchasing):** Financial settlement

### Traceability
- Complete chain: PO → GRN → Purchasing
- Batch-level tracking maintained
- Full audit trail

### Quality Control
- Only approved GRNs flow to Purchasing
- Rejected GRNs blocked
- QC status tracked per batch

---

## 🚀 Next Steps (When Purchasing Module is Built)

1. **Create Purchasing UI:**
   - List view of Purchasing Draft Payloads
   - Create Purchasing from payload
   - Edit financial fields (invoice, tax, etc.)

2. **Database Schema:**
   - Create `purchasing` table
   - Create `purchasing_items` table
   - Create `purchasing_batches` table
   - Link to GRNs

3. **Integration:**
   - Load Purchasing Draft Payloads from database
   - Create Purchasing records from payloads
   - Update GRN with `purchasingId`

---

## 📚 Code Comments

All functions include detailed inline comments explaining:
- **WHY** each rule exists (ISO 22000 compliance)
- **WHAT** the function does
- **HOW** it integrates with the flow

---

## ✅ Testing Checklist

- [x] PO approval triggers GRN draft creation
- [x] GRN draft is editable
- [x] GRN draft does NOT auto-approve
- [x] GRN approval prepares Purchasing draft payload
- [x] Direct GRN (no PO) also prepares Purchasing draft
- [x] PO status updates based on GRN status
- [x] Multiple GRNs can be merged into Purchasing
- [x] Rejected GRNs are blocked from Purchasing

---

## 📞 Support

For questions or issues with the auto-draft flow:
1. Check console logs for hook triggers
2. Verify GRN/Purchasing draft payloads in localStorage
3. Review inline code comments

---

**✅ Implementation Complete**  
**Ready for Purchasing Module Development**


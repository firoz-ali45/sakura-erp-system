# ISO 22000 / FSSC 22000 Compliant GRN System

## ✅ Complete Implementation

### 🎯 System-Generated GRN Numbers
- **Format**: `GRN-YYYYMMDD-TIMESTAMP`
- **Example**: `GRN-20251217-123456`
- **Rule**: System generates only - no manual entry allowed

### 📋 GRN Header Fields (Auto-Generated & Required)

1. **GRN Number** - System generated, unique, readonly
2. **GRN Date & Time** - Auto-filled, editable
3. **Purchase Order Number** - From purchase order
4. **Supplier Name** - Required
5. **Supplier Code** - Optional
6. **Vendor Batch Number** - **MANDATORY** (ISO requirement)
7. **Receiving Location** - Dropdown (Main Warehouse, Production Area, Cold Storage, Branch 1, Branch 2)
8. **Invoice Number** - Optional
9. **External Reference ID** - Auto-generated, editable (for Foodics integration)

### 🔍 Item Inspection Table (Per Item)

**Required Fields:**
- Item Code
- Item Description (auto-filled from purchase)
- Unit of Measure (auto-filled)
- Received Quantity
- **Expiry Date** - **MANDATORY** (blocks approval if missing)
- Packaging Condition (Good / Damaged)
- Visual Inspection (Pass / Fail)
- Temperature Check (if applicable)
- Non-Conformance Reason (shown if Visual Inspection = Fail)
- Non-Conformance Severity (Critical / Major / Minor) - shown if Fail

### ✅ Quality Decision Section

**Overall QC Status** (Required):
- **PASS** - Auto-generates batches, accepts to stock
- **HOLD** - Blocks batch generation, blocks production use
- **REJECT** - Blocks batch generation, requires return/destroy

**Disposition** (Auto-set based on QC Status):
- Accept to Stock (PASS)
- Hold for Investigation (HOLD)
- Return to Supplier (REJECT)
- Destroy (REJECT)

**Additional Fields:**
- QA Remarks (text)
- Corrective Action Required (Yes / No)

### 👤 Approval & Responsibility

**Required Sign-offs:**
1. **Received By** - Warehouse User
2. **Quality Checked By** - QA User
3. **Approved By** - QA Manager
4. **Approval Date & Time** - Auto-filled, readonly

### 🔒 Validation Rules (ISO Compliance)

1. **Expiry Date Mandatory**
   - Cannot approve GRN without expiry dates for all items
   - Validation runs on form submission
   - Error message: "Expiry date is mandatory for all items"

2. **QC HOLD Blocks Production**
   - Batches from HOLD GRN cannot be used in production
   - Error: "Cannot use batch in production. Source GRN has QC HOLD status"
   - Must change GRN status to PASS first

3. **System-Generated GRN Numbers**
   - GRN number field is readonly
   - Format enforced: `GRN-YYYYMMDD-TIMESTAMP`

4. **Vendor Batch Number Mandatory**
   - Required field for traceability
   - Links to internal batch numbers

### 🔄 Batch Auto-Generation

**When GRN is Approved (PASS status):**
- Automatically generates batch for each item
- **Batch Number Format**: `BATCH-YYMM-ITEM-VENDOR-RANDOM`
- **Example**: `BATCH-2512-FLO-ALM-123`

**Batch Contains:**
- GRN reference (grn_number, grn_id)
- Material details (code, name, quantity, unit)
- Expiry date (from GRN inspection)
- Location (from GRN)
- Vendor batch number
- QC status (inherited from GRN)
- Packaging condition
- Visual inspection result
- Temperature check
- Non-conformance details (if any)

### 📊 Traceability Chain

**Complete Flow:**
```
Purchase Order
    ↓
GRN (with QC status)
    ↓
Batch (auto-generated if PASS)
    ↓
Transfer (TRS/TRR)
    ↓
Production Lot (uses batches)
    ↓
Finished Lot
    ↓
Sale
    ↓
Adjustment (if needed)
```

**Backward Tracing:**
- Batch → GRN → Purchase Order
- Lot → Batches → GRN → Purchase Order

**Forward Tracing:**
- GRN → Batches → Production Lots → Sales
- Batch → Production Lots → Sales

### 🚫 QC HOLD Behavior

**When GRN Status = HOLD:**
1. ✅ GRN is created and saved
2. ❌ Batches are NOT auto-generated
3. ❌ Existing batches from HOLD GRN cannot be used in production
4. ✅ GRN can be viewed and edited
5. ✅ Status can be changed to PASS (requires manager approval)

**When GRN Status = REJECT:**
1. ✅ GRN is created and saved
2. ❌ Batches are NOT auto-generated
3. ❌ Disposition: Return to Supplier or Destroy
4. ✅ Full audit trail maintained

### 📝 Audit Trail

**All Actions Logged:**
- GRN creation timestamp
- Approval timestamp
- User who received
- User who quality checked
- User who approved
- Status changes
- Batch generation timestamps

### 🔗 Integration Points

1. **Purchase Orders** - GRN created from pending purchases
2. **Batch System** - Auto-generates batches on approval
3. **Stock System** - Batches appear in stock after approval
4. **Production** - Blocks HOLD batches from production
5. **Traceability** - Complete chain from GRN to sale

### 🎨 UI Features

- Professional Sakura theme colors (#284b44, #956c2a, #ea8990)
- Responsive design
- Arabic/English support
- Real-time validation
- Clear error messages
- Loading states
- Modal-based form

### 📱 Usage

1. Click "Create GRN Inspection" on purchase order
2. Fill all required fields
3. Enter expiry dates for all items
4. Set QC status (PASS/HOLD/REJECT)
5. Fill approval section
6. Submit & Approve
7. Batches auto-generated (if PASS)

---

**✅ ISO 22000 / FSSC 22000 Compliant**
**✅ Full Audit Trail**
**✅ Complete Traceability**
**✅ Production-Ready**

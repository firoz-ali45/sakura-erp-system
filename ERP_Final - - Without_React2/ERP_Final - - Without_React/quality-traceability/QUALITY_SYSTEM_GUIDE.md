# Food Quality Traceability System - Complete Guide

## 🎯 World-Class Accurate Calculations

This system implements **enterprise-grade calculations** with proper data flow:

### Data Flow Chain
```
Purchase → GRN → Batch → Transfer → Production → Lot → Sale → Adjustment
```

## 📊 Calculation Logic

### Stock Calculation (World-Class Accurate)

**Available Quantity Formula:**
```
Available = On-Hand - Reserved - Allocated - Consumed
```

**For Batches:**
- Start with: `batch.quantity`
- Subtract: Adjustments (waste/test/damage)
- Subtract: Transfers sent (TRS)
- Add: Transfers received (TRR)
- Subtract: Production consumption (proportional)

**For Production Lots:**
- Start with: `lot.quantity`
- Subtract: Sales
- Subtract: Adjustments
- Subtract: Transfers sent (TRS)
- Add: Transfers received (TRR)

### Expiry Tracking

**Days Until Expiry:**
```javascript
days = Math.ceil((expiryDate - today) / (1000 * 60 * 60 * 24))
```

**Status Badges:**
- **Expired**: days < 0 (Red)
- **Expiring Soon**: days <= 7 (Orange)
- **Near Expiry**: days <= 30 (Yellow)
- **Good**: days > 30 (Green)

## 🔄 Operations

### 1. GRN & Receiving
- Create GRN from Purchase Order
- Validates purchase exists
- Links to batches

### 2. Raw Material Batches
- Create batch from GRN
- Validates GRN reference
- Tracks available quantity
- Expiry date tracking

### 3. Production & Finished Lots
- Create lot from batches
- Validates batch sources exist
- Links batches to production
- Tracks batch consumption

### 4. Transfers (TRS / TRR)
- **TRS (Transfer Send)**: Creates pending transfer
- **TRR (Transfer Receive)**: Completes transfer
- Validates available quantity
- Updates stock locations

### 5. Sales Consumption
- Records sale from lot
- Validates available quantity
- Tracks customer/outlet

### 6. Adjustments
- Waste/Test/Damage/Expired
- Reduces available quantity
- Full audit trail

### 7. Traceability & Recall
- Complete chain from batch/lot
- Shows all transactions
- Backward and forward tracing

## ✅ Validation Rules

1. **Quantity Validation**: Must be > 0
2. **Stock Validation**: Cannot transfer/sell more than available
3. **Reference Validation**: GRN/Batch/Lot must exist
4. **Date Validation**: Expiry must be in future
5. **Location Validation**: Must be valid location

## 🗄️ Data Storage

Uses **localStorage** when backend unavailable:
- `quality_purchases`
- `quality_grns`
- `quality_batches`
- `quality_production`
- `quality_transfers`
- `quality_sales`
- `quality_adjustments`

## 🚀 Usage

### Create Sample Data

```javascript
// Create a batch
await QualityAPI.createRawBatch({
    grn_id: 'GRN-001',
    material_name: 'Flour',
    quantity: 100,
    unit: 'kg',
    expiry_date: '2025-12-31',
    location: 'Main Warehouse',
    external_reference_id: 'BATCH-001'
});

// Create production lot
await QualityAPI.createProduction({
    product_name: 'Bread',
    quantity: 50,
    unit: 'pcs',
    production_date: '2025-12-17',
    expiry_date: '2025-12-20',
    location: 'Production Area',
    batch_sources: ['BATCH-001'],
    external_reference_id: 'LOT-001'
});

// Record sale
await QualityAPI.recordSale({
    lot_id: 'LOT-001',
    quantity: 10,
    unit: 'pcs',
    customer_outlet: 'Store A',
    sale_date: '2025-12-17'
});
```

## 📈 Features

✅ **Accurate Stock Calculations**
✅ **Real-time Quantity Tracking**
✅ **Complete Traceability Chain**
✅ **Expiry Management**
✅ **Transfer Management (TRS/TRR)**
✅ **Sales Tracking**
✅ **Adjustment Handling**
✅ **Recall Simulation**

## 🔍 Testing

1. Create a batch
2. Create production lot using that batch
3. Record a sale
4. Check stock - should show reduced quantity
5. Trace the lot - should show complete chain

## 🎨 UI Features

- Arabic/English support
- Real-time updates
- Validation messages
- Error handling
- Loading states
- Responsive design

---

**All calculations are production-ready and enterprise-grade!** 🚀

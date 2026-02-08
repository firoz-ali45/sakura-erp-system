# 🚀 Complete Supabase Setup Guide - Purchase Orders, Transfer Orders & GRN

## 📋 **Overview**

Yeh guide aapko batayega ki kaise Purchase Orders, Transfer Orders, aur GRN (Goods Receipt Note) ke liye Supabase tables create karein.

---

## ✅ **Step 1: Purchase Orders Tables Create Karein**

### **File:** `CREATE_PURCHASE_ORDERS_TABLES.sql`

1. Supabase Dashboard → **SQL Editor** mein jao
2. File open karein: `CREATE_PURCHASE_ORDERS_TABLES.sql`
3. Saara SQL code copy karein
4. Supabase SQL Editor mein paste karein
5. **Run** button click karein

**Yeh create karega:**
- ✅ `purchase_orders` table
- ✅ `purchase_order_items` table
- ✅ Indexes (performance ke liye)
- ✅ RLS Policies (security ke liye)

---

## ✅ **Step 2: Transfer Orders Tables Create Karein**

### **File:** `CREATE_TRANSFER_ORDERS_TABLES.sql`

1. Supabase Dashboard → **SQL Editor** mein jao
2. File open karein: `CREATE_TRANSFER_ORDERS_TABLES.sql`
3. Saara SQL code copy karein
4. Supabase SQL Editor mein paste karein
5. **Run** button click karein

**Yeh create karega:**
- ✅ `transfer_orders` table
- ✅ `transfer_order_items` table
- ✅ Indexes (performance ke liye)
- ✅ RLS Policies (security ke liye)

---

## ✅ **Step 3: GRN Tables Create Karein**

### **File:** `CREATE_GRN_TABLES.sql`

1. Supabase Dashboard → **SQL Editor** mein jao
2. File open karein: `CREATE_GRN_TABLES.sql`
3. Saara SQL code copy karein
4. Supabase SQL Editor mein paste karein
5. **Run** button click karein

**Yeh create karega:**
- ✅ `grn_inspections` table
- ✅ `grn_inspection_items` table
- ✅ Indexes (performance ke liye)
- ✅ RLS Policies (security ke liye)

---

## 📊 **Tables Structure Summary**

### **1. Purchase Orders**
- **Main Table:** `purchase_orders`
  - PO number, supplier, dates, status, amounts, etc.
- **Items Table:** `purchase_order_items`
  - Items in each PO, quantities, prices, batches, etc.

### **2. Transfer Orders**
- **Main Table:** `transfer_orders`
  - Transfer number, from/to locations, dates, status, etc.
- **Items Table:** `transfer_order_items`
  - Items being transferred, quantities, batches, etc.

### **3. GRN (Goods Receipt Note)**
- **Main Table:** `grn_inspections`
  - GRN number, PO reference, supplier, QC status, approvals, etc.
- **Items Table:** `grn_inspection_items`
  - Items inspected, quality checks, expiry dates, non-conformance, etc.

---

## 🔒 **Security (RLS Policies)**

Har table ke liye 4 policies create hongi:
1. **SELECT** - Data read karne ke liye
2. **INSERT** - New data add karne ke liye
3. **UPDATE** - Data update karne ke liye
4. **DELETE** - Data delete karne ke liye

**Sab policies `true` condition ke saath hain** - matlab sab users ko access milega (development/testing ke liye).

---

## ✅ **Verification**

SQL run karne ke baad, verify karein:

1. **Supabase Dashboard** → **Table Editor**
2. Aapko yeh tables dikhni chahiye:
   - ✅ `purchase_orders`
   - ✅ `purchase_order_items`
   - ✅ `transfer_orders`
   - ✅ `transfer_order_items`
   - ✅ `grn_inspections`
   - ✅ `grn_inspection_items`

---

## 🎯 **Next Steps**

SQL files run karne ke baad:

1. ✅ **Frontend Integration** - Supabase service functions add honge
2. ✅ **Purchase Orders** - Supabase mein save honge
3. ✅ **Transfer Orders** - Supabase mein save honge
4. ✅ **GRN** - Supabase mein save honge

---

## 🆘 **Troubleshooting**

### **Error: "relation already exists"**
- **Fix:** Yeh normal hai agar table pehle se exist karti hai. SQL safely run ho jayega.

### **Error: "foreign key constraint"**
- **Fix:** Pehle `suppliers` table create karein (already created hai agar suppliers setup ho chuka hai).

### **Error: "permission denied"**
- **Fix:** Apne project ke admin account se login karein.

---

## 📝 **Files Created**

1. ✅ `CREATE_PURCHASE_ORDERS_TABLES.sql`
2. ✅ `CREATE_TRANSFER_ORDERS_TABLES.sql`
3. ✅ `CREATE_GRN_TABLES.sql`
4. ✅ `COMPLETE_SUPABASE_SETUP_GUIDE.md` (yeh file)

---

## 🎉 **Complete!**

Ab aapke system mein:
- ✅ Purchase Orders → Supabase mein save honge
- ✅ Transfer Orders → Supabase mein save honge
- ✅ GRN → Supabase mein save honge

**Sab kuch same database mein hoga jahan Inventory Items aur Suppliers hain!** 🚀


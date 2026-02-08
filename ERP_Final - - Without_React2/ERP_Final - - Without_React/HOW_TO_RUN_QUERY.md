# 🚀 How to Run SQL Query in SQLTools

## ✅ **Connection Active Hai!**

Aapka connection **"Supabase ERP"** already connected hai! Ab query run karein.

---

## 📋 **Query Run Karne Ke Steps:**

### **Method 1: Run Button Se (Easiest)**

1. **SQL query tab** mein query hai: `SELECT * FROM users LIMIT 10;`
2. **Top right corner** mein **"Run on active connection"** button dikhega
3. **"Run on active connection"** button click karo
   - Ya phir **"▷ Run on active connection"** icon click karo
4. **Results dikhenge** (new tab mein ya same tab mein) ✅

### **Method 2: Keyboard Shortcut**

1. **SQL query tab** mein query select karo
2. **Keyboard shortcut:** `Ctrl + Enter`
3. **Results dikhenge** ✅

### **Method 3: Right-Click Menu**

1. **Query select karo**
2. **Right-click** karo
3. **"Run Query"** ya **"Execute Query"** select karo
4. **Results dikhenge** ✅

---

## 🎯 **Quick Steps:**

1. ✅ **Query tab** mein: `SELECT * FROM users LIMIT 10;`
2. ✅ **"Run on active connection"** button click karo
   - Ya phir **`Ctrl + Enter`** press karo
3. ✅ **Results dikhenge!**

---

## 📊 **Expected Results:**

Query run karne ke baad, aapko **users table** ka data dikhega:

```
id | email | name | role | status | created_at | ...
---|-------|------|------|--------|------------|----
... | ... | ... | ... | ... | ... | ...
```

---

## 🔍 **Other Queries Try Karein:**

### **Query 1: GRN Inspections**
```sql
SELECT * FROM grn_inspections ORDER BY created_at DESC LIMIT 10;
```

### **Query 2: Inventory Items**
```sql
SELECT id, name, sku FROM inventory_items LIMIT 10;
```

### **Query 3: Tables List**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'erp';
```

---

## ✅ **Verify: Query Run Ho Rahi Hai?**

### **Check 1: Results Tab**
- Query run karne ke baad **new tab** khulega
- **Results table** dikhega
- **Rows count** dikhega

### **Check 2: Status Bar**
- **"Query executed successfully"** dikhe
- Ya phir **execution time** dikhe

### **Check 3: Error Messages**
- Agar error aaye, to **red error message** dikhega
- Error details check karo

---

## 🆘 **Agar Query Run Nahi Ho Raha:**

### **Problem 1: "No active connection" Error**

**Solution:**
1. **Connection dropdown** check karo (top right)
2. **"Supabase ERP"** select karo
3. **Phir se query run karo**

### **Problem 2: Query Syntax Error**

**Solution:**
1. **SQL syntax check karo**
2. **Semicolon (;)** end mein hai?
3. **Table name** sahi hai?
4. **Column names** sahi hain?

### **Problem 3: Table Not Found**

**Solution:**
1. **Left sidebar** mein **Tables** folder check karo
2. **Table exist karti hai** ya nahi verify karo
3. **Schema name** check karo (`erp` schema mein tables hain)

---

## 🎯 **Quick Reference:**

| Action | Method | Shortcut |
|--------|--------|----------|
| **Run Query** | Button click | `Ctrl + Enter` |
| **New Query** | SQLTools panel | `Ctrl + Shift + Q` |
| **Show Results** | Results tab | Auto-open |
| **Cancel Query** | Stop button | `Esc` |

---

## 🎉 **Summary:**

1. ✅ **Connection active hai**
2. ✅ **Query ready hai:** `SELECT * FROM users LIMIT 10;`
3. ✅ **"Run on active connection"** button click karo
4. ✅ **Results dikhenge!**

**Ab query run karo aur results dekho! 🚀**

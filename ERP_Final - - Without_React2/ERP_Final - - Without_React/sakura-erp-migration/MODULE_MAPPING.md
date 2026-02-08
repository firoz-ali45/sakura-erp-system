# Sakura ERP Module Mapping Table

Complete mapping of old HTML/JS system to new Vue 3 + Express.js architecture.

## Overview

This document maps each module, page, and functionality from the original HTML-based system to the new Vue 3 + Express.js + Prisma architecture.

---

## Module: Home Portal (Dashboard)

| Old System | New System | Status |
|------------|-----------|--------|
| `index.html` (Home Portal) | `frontend/src/views/HomePortal.vue` | ✅ To be migrated |
| Dashboard loader JS | Vue component `onMounted` hook | ✅ Architecture ready |
| Supabase client-side queries | Express API `/api/dashboard` | ⏳ To be implemented |

---

## Module: Inventory

### Sub-module: Items

| Old System | New System | Status |
|------------|-----------|--------|
| `inventory/items.html` | `frontend/src/views/inventory/Items.vue` | ✅ Migrated |
| Inline JavaScript functions | Vue Composition API (`<script setup>`) | ✅ Migrated |
| `supabase.from('inventory_items')` | `GET /api/inventory/items` | ✅ Implemented |
| `supabase.from('inventory_items').insert()` | `POST /api/inventory/items` | ✅ Implemented |
| `supabase.from('inventory_items').update()` | `PUT /api/inventory/items/:id` | ✅ Implemented |
| `supabase.from('inventory_items').update({deleted: true})` | `DELETE /api/inventory/items/:id` | ✅ Implemented |
| Excel import/export logic | `POST /api/inventory/items/bulk-import` | ✅ Implemented |
| Bulk actions (tags, category, delete) | Same Vue component methods | ✅ Migrated |
| Tab filtering (All, Items, Products, Deleted) | Vue computed properties | ✅ Migrated |
| Modal dialogs (Create, Edit, Import) | Vue components with v-if | ✅ Migrated |

### Sub-module: Item Detail

| Old System | New System | Status |
|------------|-----------|--------|
| `inventory/item-detail.html` | `frontend/src/views/inventory/ItemDetail.vue` | ⏳ To be migrated |
| Item detail view logic | Vue component with route params | ⏳ To be migrated |

### Sub-module: Categories

| Old System | New System | Status |
|------------|-----------|--------|
| `inventory/categories.html` | `frontend/src/views/inventory/Categories.vue` | ⏳ To be migrated |
| Category CRUD operations | `GET/POST /api/inventory/categories` | ✅ Implemented |

### Sub-module: More (Suppliers, Purchase Orders, etc.)

| Old System | New System | Status |
|------------|-----------|--------|
| `inventory/more.html` | `frontend/src/views/inventory/More.vue` | ⏳ To be migrated |
| Suppliers management | `GET /api/purchase-orders/suppliers` | ✅ Implemented |
| Purchase Orders | `frontend/src/views/purchase-orders/PurchaseOrders.vue` | ⏳ To be migrated |
| Transfer Orders | `GET/POST /api/transfer-orders` | ⏳ To be implemented |
| Inventory Count | `GET/POST /api/inventory-counts` | ⏳ To be implemented |
| Production | `GET/POST /api/productions` | ⏳ To be implemented |

---

## Module: Purchase Orders

| Old System | New System | Status |
|------------|-----------|--------|
| Purchase Orders HTML (in `inventory/more.html`) | `frontend/src/views/purchase-orders/PurchaseOrders.vue` | ⏳ To be migrated |
| PO creation form | Vue component form | ⏳ To be migrated |
| PO items table | Vue component with v-for | ⏳ To be migrated |
| VAT calculations | Backend API (preserved logic) | ✅ Implemented |
| Batch/expiry tracking | Prisma schema fields | ✅ Implemented |
| `GET /api/purchase-orders` | ✅ Implemented |
| `POST /api/purchase-orders` | ✅ Implemented |
| `PUT /api/purchase-orders/:id` | ✅ Implemented |

---

## Module: Manage

### Sub-module: Tags

| Old System | New System | Status |
|------------|-----------|--------|
| `manage/tags.html` | `frontend/src/views/manage/Tags.vue` | ⏳ To be migrated |
| Tags CRUD | `GET/POST/PUT/DELETE /api/tags` | ⏳ To be implemented |

---

## Module: Reports

### Sub-module: Accounts Payable

| Old System | New System | Status |
|------------|-----------|--------|
| `sakura-accounts-payable-dashboard/payable.html` | `frontend/src/views/reports/AccountsPayable.vue` | ⏳ To be migrated |
| AP report logic | `GET /api/reports/accounts-payable` | ✅ Implemented |

### Sub-module: RM Forecasting

| Old System | New System | Status |
|------------|-----------|--------|
| `sakura-accounts-payable-dashboard/forecasting.html` | `frontend/src/views/reports/Forecasting.vue` | ⏳ To be migrated |
| Forecasting calculations | `GET /api/reports/forecasting` | ⏳ To be implemented |

### Sub-module: Warehouse Dashboard

| Old System | New System | Status |
|------------|-----------|--------|
| `sakura-accounts-payable-dashboard/Warehouse.html` | `frontend/src/views/reports/Warehouse.vue` | ⏳ To be migrated |
| Warehouse dashboard logic | `GET /api/reports/warehouse` | ⏳ To be implemented |

### Sub-module: Food Quality Traceability

| Old System | New System | Status |
|------------|-----------|--------|
| `quality-traceability/quality-dashboard.html` | `frontend/src/views/quality/QualityDashboard.vue` | ⏳ To be migrated |
| GRN Inspection | `GET/POST /api/quality/grn-inspections` | ⏳ To be implemented |
| Quality API logic | Express routes | ⏳ To be implemented |

### Sub-module: User Management

| Old System | New System | Status |
|------------|-----------|--------|
| User management HTML | `frontend/src/views/users/UserManagement.vue` | ⏳ To be migrated |
| User CRUD operations | `GET /api/users` (admin only) | ✅ Implemented |

---

## Module: Settings

| Old System | New System | Status |
|------------|-----------|--------|
| Settings HTML | `frontend/src/views/Settings.vue` | ⏳ To be migrated |
| System settings | `GET/PUT /api/settings` | ⏳ To be implemented |

---

## Authentication & Authorization

| Old System | New System | Status |
|------------|-----------|--------|
| Supabase Auth | JWT-based auth with Express | ✅ Implemented |
| `js/config.js` (ACCESS_PASSWORD) | JWT token in Authorization header | ✅ Implemented |
| Role-based access | Express middleware `authorize()` | ✅ Implemented |
| Permission checks | Express middleware `requirePermission()` | ✅ Implemented |
| User session management | JWT token + `user_sessions` table | ✅ Implemented |

---

## Navigation & Routing

| Old System | New System | Status |
|------------|-----------|--------|
| `js/router.js` (SakuraRouter class) | Vue Router (`vue-router`) | ✅ Implemented |
| `js/routes.js` (route definitions) | `frontend/src/router/index.js` | ✅ Implemented |
| Client-side routing | Vue Router with history mode | ✅ Implemented |
| Route guards | Vue Router `beforeEach` guard | ✅ Implemented |

---

## Data Layer

| Old System | New System | Status |
|------------|-----------|--------|
| Supabase client (browser) | Express.js API + Prisma ORM | ✅ Implemented |
| Direct Supabase queries | REST API endpoints | ✅ Implemented |
| `supabase.from('table').select()` | `GET /api/resource` | ✅ Implemented |
| `supabase.from('table').insert()` | `POST /api/resource` | ✅ Implemented |
| `supabase.from('table').update()` | `PUT /api/resource/:id` | ✅ Implemented |
| `supabase.from('table').delete()` | `DELETE /api/resource/:id` | ✅ Implemented |
| Row Level Security (RLS) | Express middleware + Prisma | ✅ Implemented |

---

## UI Components & Styling

| Old System | New System | Status |
|------------|-----------|--------|
| Tailwind CSS (CDN) | Tailwind CSS (npm package) | ✅ Implemented |
| Inline styles | Vue scoped styles + Tailwind | ✅ Migrated |
| Font Awesome (CDN) | Font Awesome (CDN - same) | ✅ Same |
| Google Fonts (Cairo) | Google Fonts (Cairo - same) | ✅ Same |
| Custom notification system | Vue component (to be created) | ⏳ To be migrated |
| Modal dialogs | Vue components with v-if | ✅ Migrated |
| Dropdown menus | Vue components | ✅ Migrated |

---

## Business Logic Preservation

| Feature | Old System | New System | Status |
|---------|------------|------------|--------|
| VAT calculations | JavaScript functions | Express API (same logic) | ✅ Preserved |
| Costing methods | Item field | Prisma schema field | ✅ Preserved |
| Batch tracking | JSONB fields | Prisma schema fields | ✅ Preserved |
| Expiry date tracking | DateTime fields | Prisma DateTime fields | ✅ Preserved |
| Stock levels (min/max/par) | Text fields | Prisma schema fields | ✅ Preserved |
| Soft delete | `deleted` boolean | Prisma schema `deleted` field | ✅ Preserved |
| Audit logging | Supabase triggers | Prisma + Express middleware | ✅ Implemented |
| Activity tracking | `user_activities` table | Same Prisma model | ✅ Preserved |

---

## File Structure Mapping

### Old Structure
```
/
├── index.html
├── inventory/
│   ├── items.html
│   ├── item-detail.html
│   ├── categories.html
│   └── more.html
├── manage/
│   └── tags.html
├── quality-traceability/
│   └── quality-dashboard.html
├── sakura-accounts-payable-dashboard/
│   ├── payable.html
│   ├── forecasting.html
│   └── Warehouse.html
├── js/
│   ├── router.js
│   ├── routes.js
│   ├── config.js
│   └── ...
└── css/
    └── core.css
```

### New Structure
```
sakura-erp-migration/
├── frontend/
│   ├── src/
│   │   ├── views/
│   │   │   ├── HomePortal.vue
│   │   │   ├── Login.vue
│   │   │   ├── inventory/
│   │   │   │   ├── Items.vue ✅
│   │   │   │   ├── ItemDetail.vue
│   │   │   │   ├── Categories.vue
│   │   │   │   └── More.vue
│   │   │   ├── purchase-orders/
│   │   │   │   └── PurchaseOrders.vue
│   │   │   ├── manage/
│   │   │   │   └── Tags.vue
│   │   │   ├── reports/
│   │   │   │   ├── AccountsPayable.vue
│   │   │   │   ├── Forecasting.vue
│   │   │   │   └── Warehouse.vue
│   │   │   └── quality/
│   │   │       └── QualityDashboard.vue
│   │   ├── services/
│   │   │   ├── api.js ✅
│   │   │   └── inventory.js ✅
│   │   ├── stores/
│   │   │   └── auth.js ✅
│   │   ├── router/
│   │   │   └── index.js ✅
│   │   └── App.vue ✅
│   └── package.json ✅
├── backend/
│   ├── src/
│   │   ├── routes/
│   │   │   ├── auth.js ✅
│   │   │   ├── inventory.js ✅
│   │   │   ├── purchaseOrders.js ✅
│   │   │   ├── users.js ✅
│   │   │   └── reports.js ✅
│   │   ├── middleware/
│   │   │   └── auth.js ✅
│   │   └── server.js ✅
│   └── package.json ✅
└── prisma/
    └── schema.prisma ✅
```

---

## Migration Status Summary

- ✅ **Completed**: Core architecture, Inventory Items module, Authentication, API structure
- ⏳ **In Progress**: Purchase Orders component
- 📋 **Pending**: Remaining views, Reports modules, Quality Traceability, Settings

---

## Notes

1. **100% Functional Parity**: All business logic, calculations, and data structures are preserved
2. **No Refactoring**: Code structure mirrors original as closely as possible
3. **Same UI/UX**: Vue components maintain exact same HTML structure and Tailwind classes
4. **Database Schema**: Prisma schema exactly mirrors existing Supabase tables
5. **API Endpoints**: RESTful API replaces direct Supabase client calls


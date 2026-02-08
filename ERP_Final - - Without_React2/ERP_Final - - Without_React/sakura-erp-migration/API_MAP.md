# Sakura ERP API Map

Complete API endpoint documentation for the migrated ERP system.

## Base URL
```
http://localhost:3000/api
```

## Authentication

All protected endpoints require JWT token in Authorization header:
```
Authorization: Bearer <token>
```

---

## Auth Endpoints

### POST /api/auth/login
User login

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "User Name",
      "role": "admin",
      "status": "active",
      "permissions": {}
    },
    "token": "jwt_token_here"
  }
}
```

### GET /api/auth/me
Get current authenticated user

**Response:**
```json
{
  "success": true,
  "data": {
    "user": { ... }
  }
}
```

### POST /api/auth/logout
Logout (logs activity)

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## Inventory Endpoints

### GET /api/inventory/items
Get all inventory items

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 50, max: 100)
- `search` (optional): Search term (searches name, nameLocalized, sku, barcode)
- `category` (optional): Filter by category
- `deleted` (optional): Include deleted items (true/false)

**Response:**
```json
{
  "success": true,
  "data": {
    "items": [...],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 100,
      "totalPages": 2
    }
  }
}
```

### GET /api/inventory/items/:id
Get single inventory item

**Response:**
```json
{
  "success": true,
  "data": {
    "item": { ... }
  }
}
```

### POST /api/inventory/items
Create new inventory item

**Request:**
```json
{
  "name": "Item Name",
  "nameLocalized": "Item Name (Localized)",
  "inventoryItemId": "ITEM-001",
  "sku": "SKU-001",
  "category": "Category Name",
  "categoryId": "uuid",
  "storageUnit": "Kg",
  "ingredientUnit": "Pcs",
  "storageToIngredient": 1,
  "costingMethod": "From Transactions",
  "cost": 10.50,
  "barcode": "123456789",
  "minLevel": "10",
  "maxLevel": "100",
  "parLevel": "50",
  "tags": [],
  "ingredients": [],
  "suppliers": []
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "item": { ... }
  }
}
```

### PUT /api/inventory/items/:id
Update inventory item

**Request:** (same structure as POST, all fields optional)

**Response:**
```json
{
  "success": true,
  "data": {
    "item": { ... }
  }
}
```

### DELETE /api/inventory/items/:id
Soft delete inventory item

**Response:**
```json
{
  "success": true,
  "message": "Item deleted successfully",
  "data": {
    "item": { ... }
  }
}
```

### POST /api/inventory/items/:id/restore
Restore soft-deleted item

**Response:**
```json
{
  "success": true,
  "message": "Item restored successfully",
  "data": {
    "item": { ... }
  }
}
```

### GET /api/inventory/categories
Get all inventory categories

**Query Parameters:**
- `deleted` (optional): Include deleted categories (true/false)

**Response:**
```json
{
  "success": true,
  "data": {
    "categories": [...]
  }
}
```

### POST /api/inventory/categories
Create new category

**Request:**
```json
{
  "name": "Category Name",
  "nameLocalized": "Category Name (Localized)",
  "reference": "REF-001"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "category": { ... }
  }
}
```

### POST /api/inventory/items/bulk-import
Bulk import items from Excel/CSV

**Request:**
```json
{
  "items": [
    {
      "name": "Item 1",
      "sku": "SKU-001",
      "storageUnit": "Kg",
      "ingredientUnit": "Pcs",
      ...
    },
    ...
  ]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "created": 10,
    "total": 10
  }
}
```

---

## Purchase Orders Endpoints

### GET /api/purchase-orders
Get all purchase orders

**Query Parameters:**
- `page` (optional): Page number
- `limit` (optional): Items per page
- `status` (optional): Filter by status (pending, received, partial, completed, cancelled)
- `supplierId` (optional): Filter by supplier UUID

**Response:**
```json
{
  "success": true,
  "data": {
    "orders": [
      {
        "id": "uuid",
        "poNumber": "PO-001",
        "supplier": { ... },
        "items": [
          {
            "id": "uuid",
            "item": { ... },
            "quantity": 10,
            "unitPrice": 5.50,
            "vatRate": 5,
            "vatAmount": 2.75,
            "totalAmount": 57.75
          }
        ],
        "totalAmount": 100.00,
        "vatAmount": 5.00,
        "status": "pending",
        "orderDate": "2024-01-01T00:00:00Z"
      }
    ],
    "pagination": { ... }
  }
}
```

### GET /api/purchase-orders/:id
Get single purchase order

**Response:**
```json
{
  "success": true,
  "data": {
    "order": { ... }
  }
}
```

### POST /api/purchase-orders
Create new purchase order

**Request:**
```json
{
  "poNumber": "PO-001",
  "supplierId": "uuid",
  "orderDate": "2024-01-01T00:00:00Z",
  "expectedDate": "2024-01-15T00:00:00Z",
  "status": "pending",
  "notes": "Order notes",
  "items": [
    {
      "itemId": "uuid",
      "quantity": 10,
      "unitPrice": 5.50,
      "vatRate": 5,
      "batchNumber": "BATCH-001",
      "expiryDate": "2025-01-01T00:00:00Z"
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "order": { ... }
  }
}
```

### PUT /api/purchase-orders/:id
Update purchase order

**Request:**
```json
{
  "status": "received",
  "expectedDate": "2024-01-20T00:00:00Z",
  "notes": "Updated notes"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "order": { ... }
  }
}
```

### GET /api/purchase-orders/suppliers
Get all suppliers

**Response:**
```json
{
  "success": true,
  "data": {
    "suppliers": [...]
  }
}
```

---

## Users Endpoints

### GET /api/users
Get all users (Admin only)

**Response:**
```json
{
  "success": true,
  "data": {
    "users": [...]
  }
}
```

---

## Reports Endpoints

### GET /api/reports/accounts-payable
Get Accounts Payable Report

**Response:**
```json
{
  "success": true,
  "data": {
    "orders": [
      {
        "id": "uuid",
        "poNumber": "PO-001",
        "supplier": { ... },
        "totalAmount": 100.00,
        "status": "pending"
      }
    ]
  }
}
```

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "success": false,
  "error": "Error message here",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format"
    }
  ]
}
```

**HTTP Status Codes:**
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `500` - Internal Server Error


/**
 * Inventory domain types.
 */

export interface InventoryItem {
  id: string;
  name: string;
  sku?: string;
  category_id?: string;
  unit_of_measure?: string;
  reorder_level?: number;
  reorder_quantity?: number;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface InventoryCategory {
  id: string;
  name: string;
  parent_id?: string;
  deleted?: boolean;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface InventoryLocation {
  id: string;
  name: string;
  warehouse_id?: string;
  is_default?: boolean;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface StockLedgerEntry {
  id: string;
  item_id: string;
  location_id: string;
  quantity: number;
  movement_type: string;
  reference_type?: string;
  reference_id?: string;
  created_at?: string;
  [key: string]: unknown;
}

export interface InventoryBatch {
  id: string;
  item_id: string;
  batch_number?: string;
  quantity: number;
  location_id?: string;
  expiry_date?: string;
  created_at?: string;
  [key: string]: unknown;
}

export interface StockLevel {
  item_id: string;
  location_id: string;
  quantity: number;
  item_name?: string;
  location_name?: string;
}

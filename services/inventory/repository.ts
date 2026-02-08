/**
 * Inventory repository interface.
 * Implement with Supabase client (in backend) or mock (in tests).
 */

import type {
  InventoryItem,
  InventoryCategory,
  InventoryLocation,
  StockLedgerEntry,
  InventoryBatch,
  StockLevel,
} from './types';

export interface IInventoryRepository {
  getItemById(id: string): Promise<InventoryItem | null>;
  getItems(filters?: { category_id?: string; is_active?: boolean }): Promise<InventoryItem[]>;
  createItem(item: Omit<InventoryItem, 'id' | 'created_at' | 'updated_at'>): Promise<InventoryItem>;
  updateItem(id: string, updates: Partial<InventoryItem>): Promise<InventoryItem | null>;
  getCategories(includeDeleted?: boolean): Promise<InventoryCategory[]>;
  getCategoryById(id: string): Promise<InventoryCategory | null>;
  getLocations(warehouseId?: string): Promise<InventoryLocation[]>;
  getStockByItemAndLocation(itemId: string, locationId: string): Promise<number>;
  getStockLevels(locationId?: string): Promise<StockLevel[]>;
  insertLedgerEntry(entry: Omit<StockLedgerEntry, 'id' | 'created_at'>): Promise<StockLedgerEntry>;
  getBatchesByItem(itemId: string): Promise<InventoryBatch[]>;
}

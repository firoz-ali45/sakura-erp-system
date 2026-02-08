/**
 * Inventory service — public API.
 * Use via dependency injection: pass IInventoryRepository to the service.
 */

import type { IInventoryRepository } from './repository';
import type { InventoryItem, StockLevel } from './types';
import { NotFoundError, ValidationError } from '../../backend/shared/errors';

export type InventoryServiceDeps = {
  repository: IInventoryRepository;
};

export class InventoryService {
  constructor(private deps: InventoryServiceDeps) {}

  async getItemById(id: string): Promise<InventoryItem> {
    const item = await this.deps.repository.getItemById(id);
    if (!item) throw new NotFoundError('InventoryItem', id);
    return item;
  }

  async getItems(filters?: { category_id?: string; is_active?: boolean }): Promise<InventoryItem[]> {
    return this.deps.repository.getItems(filters);
  }

  async createItem(
    input: Omit<InventoryItem, 'id' | 'created_at' | 'updated_at'>
  ): Promise<InventoryItem> {
    if (!input.name?.trim()) throw new ValidationError('Item name is required');
    return this.deps.repository.createItem(input);
  }

  async updateItem(id: string, updates: Partial<InventoryItem>): Promise<InventoryItem> {
    const existing = await this.deps.repository.getItemById(id);
    if (!existing) throw new NotFoundError('InventoryItem', id);
    const updated = await this.deps.repository.updateItem(id, updates);
    if (!updated) throw new NotFoundError('InventoryItem', id);
    return updated;
  }

  async getStockLevels(locationId?: string): Promise<StockLevel[]> {
    return this.deps.repository.getStockLevels(locationId);
  }

  async getStockForItemAtLocation(itemId: string, locationId: string): Promise<number> {
    return this.deps.repository.getStockByItemAndLocation(itemId, locationId);
  }
}

export type { InventoryItem, StockLevel } from './types';
export type { IInventoryRepository } from './repository';

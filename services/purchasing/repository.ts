/**
 * Purchasing repository interface.
 */

import type {
  PurchaseRequest,
  PurchaseRequestItem,
  PurchaseOrder,
  PurchaseOrderItem,
  Supplier,
  GrnHeader,
  GrnItem,
} from './types';

export interface IPurchasingRepository {
  getPurchaseRequestById(id: string): Promise<PurchaseRequest | null>;
  getPurchaseRequests(filters?: { status?: string }): Promise<PurchaseRequest[]>;
  createPurchaseRequest(
    pr: Omit<PurchaseRequest, 'id' | 'created_at' | 'updated_at'>
  ): Promise<PurchaseRequest>;
  updatePurchaseRequest(id: string, updates: Partial<PurchaseRequest>): Promise<PurchaseRequest | null>;
  getPurchaseRequestItems(prId: string): Promise<PurchaseRequestItem[]>;
  createPurchaseRequestItem(
    item: Omit<PurchaseRequestItem, 'id' | 'created_at'>
  ): Promise<PurchaseRequestItem>;

  getPurchaseOrderById(id: string): Promise<PurchaseOrder | null>;
  getPurchaseOrders(filters?: { status?: string; supplier_id?: string }): Promise<PurchaseOrder[]>;
  createPurchaseOrder(
    po: Omit<PurchaseOrder, 'id' | 'created_at' | 'updated_at'>
  ): Promise<PurchaseOrder>;
  getPurchaseOrderItems(poId: string): Promise<PurchaseOrderItem[]>;

  getSupplierById(id: string): Promise<Supplier | null>;
  getSuppliers(activeOnly?: boolean): Promise<Supplier[]>;
  createSupplier(supplier: Omit<Supplier, 'id' | 'created_at' | 'updated_at'>): Promise<Supplier>;

  createGrn(grn: Omit<GrnHeader, 'id' | 'created_at'>): Promise<GrnHeader>;
  createGrnItem(item: Omit<GrnItem, 'id' | 'created_at'>): Promise<GrnItem>;
}

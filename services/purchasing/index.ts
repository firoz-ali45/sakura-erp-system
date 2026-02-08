/**
 * Purchasing service — public API.
 */

import type { IPurchasingRepository } from './repository';
import type { PurchaseRequest, PurchaseOrder, Supplier } from './types';
import { NotFoundError, ValidationError } from '../../backend/shared/errors';

export type PurchasingServiceDeps = {
  repository: IPurchasingRepository;
};

export class PurchasingService {
  constructor(private deps: PurchasingServiceDeps) {}

  async getPurchaseRequestById(id: string): Promise<PurchaseRequest> {
    const pr = await this.deps.repository.getPurchaseRequestById(id);
    if (!pr) throw new NotFoundError('PurchaseRequest', id);
    return pr;
  }

  async getPurchaseRequests(filters?: { status?: string }): Promise<PurchaseRequest[]> {
    return this.deps.repository.getPurchaseRequests(filters);
  }

  async createPurchaseRequest(
    input: Omit<PurchaseRequest, 'id' | 'created_at' | 'updated_at'>
  ): Promise<PurchaseRequest> {
    if (!input.title?.trim()) throw new ValidationError('Purchase request title is required');
    return this.deps.repository.createPurchaseRequest(input);
  }

  async updatePurchaseRequestStatus(id: string, status: string): Promise<PurchaseRequest> {
    const pr = await this.deps.repository.getPurchaseRequestById(id);
    if (!pr) throw new NotFoundError('PurchaseRequest', id);
    const updated = await this.deps.repository.updatePurchaseRequest(id, { status });
    if (!updated) throw new NotFoundError('PurchaseRequest', id);
    return updated;
  }

  async getPurchaseOrderById(id: string): Promise<PurchaseOrder> {
    const po = await this.deps.repository.getPurchaseOrderById(id);
    if (!po) throw new NotFoundError('PurchaseOrder', id);
    return po;
  }

  async getPurchaseOrders(filters?: { status?: string; supplier_id?: string }): Promise<PurchaseOrder[]> {
    return this.deps.repository.getPurchaseOrders(filters);
  }

  async getSupplierById(id: string): Promise<Supplier> {
    const supplier = await this.deps.repository.getSupplierById(id);
    if (!supplier) throw new NotFoundError('Supplier', id);
    return supplier;
  }

  async getSuppliers(activeOnly = true): Promise<Supplier[]> {
    return this.deps.repository.getSuppliers(activeOnly);
  }

  async createSupplier(
    input: Omit<Supplier, 'id' | 'created_at' | 'updated_at'>
  ): Promise<Supplier> {
    if (!input.name?.trim()) throw new ValidationError('Supplier name is required');
    return this.deps.repository.createSupplier(input);
  }
}

export type { PurchaseRequest, PurchaseOrder, Supplier } from './types';
export type { IPurchasingRepository } from './repository';

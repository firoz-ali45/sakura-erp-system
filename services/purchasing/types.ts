/**
 * Purchasing domain types.
 */

export interface PurchaseRequest {
  id: string;
  pr_number?: string;
  title: string;
  status: string;
  requested_by?: string;
  department_id?: string;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface PurchaseRequestItem {
  id: string;
  purchase_request_id: string;
  item_id?: string;
  description: string;
  quantity: number;
  unit?: string;
  estimated_unit_price?: number;
  created_at?: string;
  [key: string]: unknown;
}

export interface PurchaseOrder {
  id: string;
  po_number?: string;
  supplier_id: string;
  status: string;
  order_date?: string;
  expected_date?: string;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface PurchaseOrderItem {
  id: string;
  purchase_order_id: string;
  item_id?: string;
  description: string;
  quantity: number;
  unit_price?: number;
  received_quantity?: number;
  created_at?: string;
  [key: string]: unknown;
}

export interface Supplier {
  id: string;
  name: string;
  code?: string;
  contact_email?: string;
  contact_phone?: string;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface GrnHeader {
  id: string;
  grn_number?: string;
  purchase_order_id: string;
  received_at?: string;
  status?: string;
  created_at?: string;
  [key: string]: unknown;
}

export interface GrnItem {
  id: string;
  grn_id: string;
  purchase_order_item_id: string;
  quantity_received: number;
  created_at?: string;
  [key: string]: unknown;
}

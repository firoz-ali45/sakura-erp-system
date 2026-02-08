/**
 * Document flow engine domain types.
 */

export interface DocumentFlow {
  id: string;
  document_type: string; // e.g. purchase_request, purchase_order, grn
  document_id: string;
  current_step?: string;
  status: string; // draft, pending_approval, approved, rejected, completed
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface DocumentFlowStep {
  id: string;
  flow_id: string;
  step_key: string;
  step_name: string;
  order_index: number;
  assigned_role_id?: string;
  assigned_user_id?: string;
  status: string; // pending, approved, rejected
  completed_at?: string;
  created_at?: string;
  [key: string]: unknown;
}

export interface DocGraphNode {
  id: string;
  document_type: string;
  document_id: string;
  root_document_type?: string;
  root_document_id?: string;
  parent_document_type?: string;
  parent_document_id?: string;
  created_at?: string;
  [key: string]: unknown;
}

export interface WorkflowStep {
  id: string;
  workflow_key: string;
  step_key: string;
  step_name: string;
  order_index: number;
  required_role_id?: string;
  created_at?: string;
  [key: string]: unknown;
}

export interface ApprovalAction {
  flowId: string;
  stepId: string;
  action: 'approve' | 'reject';
  comment?: string;
  userId: string;
}

/**
 * Document flow engine repository interface.
 */

import type { DocumentFlow, DocumentFlowStep, DocGraphNode, WorkflowStep } from './types';

export interface IDocumentFlowRepository {
  getFlowById(id: string): Promise<DocumentFlow | null>;
  getFlowByDocument(documentType: string, documentId: string): Promise<DocumentFlow | null>;
  getFlowsByStatus(status: string): Promise<DocumentFlow[]>;
  createFlow(
    flow: Omit<DocumentFlow, 'id' | 'created_at' | 'updated_at'>
  ): Promise<DocumentFlow>;
  updateFlow(id: string, updates: Partial<DocumentFlow>): Promise<DocumentFlow | null>;

  getStepsByFlowId(flowId: string): Promise<DocumentFlowStep[]>;
  getCurrentStep(flowId: string): Promise<DocumentFlowStep | null>;
  createStep(
    step: Omit<DocumentFlowStep, 'id' | 'created_at'>
  ): Promise<DocumentFlowStep>;
  updateStep(id: string, updates: Partial<DocumentFlowStep>): Promise<DocumentFlowStep | null>;

  getDocGraphRoot(documentType: string, documentId: string): Promise<DocGraphNode | null>;
  getDocGraphChildren(documentType: string, documentId: string): Promise<DocGraphNode[]>;
  upsertDocGraphNode(
    node: Omit<DocGraphNode, 'id' | 'created_at'>
  ): Promise<DocGraphNode>;

  getWorkflowSteps(workflowKey: string): Promise<WorkflowStep[]>;
}

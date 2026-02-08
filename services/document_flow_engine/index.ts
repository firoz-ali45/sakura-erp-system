/**
 * Document flow engine service — public API.
 * Manages workflows, approval chains, and document lineage (PR → PO → GRN).
 */

import type { IDocumentFlowRepository } from './repository';
import type { DocumentFlow, DocumentFlowStep, ApprovalAction } from './types';
import { NotFoundError, ValidationError } from '../../backend/shared/errors';

export type DocumentFlowEngineServiceDeps = {
  repository: IDocumentFlowRepository;
};

export class DocumentFlowEngineService {
  constructor(private deps: DocumentFlowEngineServiceDeps) {}

  async getFlowById(id: string): Promise<DocumentFlow> {
    const flow = await this.deps.repository.getFlowById(id);
    if (!flow) throw new NotFoundError('DocumentFlow', id);
    return flow;
  }

  async getFlowByDocument(documentType: string, documentId: string): Promise<DocumentFlow | null> {
    return this.deps.repository.getFlowByDocument(documentType, documentId);
  }

  async getFlowWithSteps(id: string): Promise<DocumentFlow & { steps: DocumentFlowStep[] }> {
    const flow = await this.getFlowById(id);
    const steps = await this.deps.repository.getStepsByFlowId(id);
    return { ...flow, steps };
  }

  async createFlow(
    input: Omit<DocumentFlow, 'id' | 'created_at' | 'updated_at'>
  ): Promise<DocumentFlow> {
    if (!input.document_type || !input.document_id)
      throw new ValidationError('document_type and document_id are required');
    return this.deps.repository.createFlow(input);
  }

  async advanceFlow(id: string, updates: Partial<DocumentFlow>): Promise<DocumentFlow> {
    const flow = await this.deps.repository.getFlowById(id);
    if (!flow) throw new NotFoundError('DocumentFlow', id);
    const updated = await this.deps.repository.updateFlow(id, updates);
    if (!updated) throw new NotFoundError('DocumentFlow', id);
    return updated;
  }

  async processApprovalAction(action: ApprovalAction): Promise<DocumentFlowStep> {
    const step = await this.deps.repository.updateStep(action.stepId, {
      status: action.action === 'approve' ? 'approved' : 'rejected',
      completed_at: new Date().toISOString(),
    });
    if (!step) throw new NotFoundError('DocumentFlowStep', action.stepId);
    await this.deps.repository.updateFlow(action.flowId, {
      current_step: action.action === 'approve' ? undefined : step.step_key,
      status: action.action === 'approve' ? 'approved' : 'rejected',
    });
    return step;
  }

  async getCurrentStep(flowId: string): Promise<DocumentFlowStep | null> {
    return this.deps.repository.getCurrentStep(flowId);
  }
}

export type { DocumentFlow, DocumentFlowStep, ApprovalAction } from './types';
export type { IDocumentFlowRepository } from './repository';

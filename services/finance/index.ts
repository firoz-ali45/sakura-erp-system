/**
 * Finance service — public API.
 */

import type { IFinanceRepository } from './repository';
import type { ChartOfAccountsEntry, GlJournal, GlJournalLine, FinancePayment } from './types';
import { NotFoundError, ValidationError } from '../../backend/shared/errors';

export type FinanceServiceDeps = {
  repository: IFinanceRepository;
};

export class FinanceService {
  constructor(private deps: FinanceServiceDeps) {}

  async getAccountById(id: string): Promise<ChartOfAccountsEntry> {
    const account = await this.deps.repository.getAccountById(id);
    if (!account) throw new NotFoundError('ChartOfAccountsEntry', id);
    return account;
  }

  async getAccounts(filters?: { account_type?: string; is_active?: boolean }): Promise<ChartOfAccountsEntry[]> {
    return this.deps.repository.getAccounts(filters);
  }

  async createAccount(
    input: Omit<ChartOfAccountsEntry, 'id' | 'created_at' | 'updated_at'>
  ): Promise<ChartOfAccountsEntry> {
    if (!input.code?.trim() || !input.name?.trim())
      throw new ValidationError('Account code and name are required');
    return this.deps.repository.createAccount(input);
  }

  async getJournalById(id: string): Promise<GlJournal> {
    const journal = await this.deps.repository.getJournalById(id);
    if (!journal) throw new NotFoundError('GlJournal', id);
    return journal;
  }

  async getJournalWithLines(id: string): Promise<GlJournal & { lines: GlJournalLine[] }> {
    const journal = await this.getJournalById(id);
    const lines = await this.deps.repository.getJournalLines(id);
    return { ...journal, lines };
  }

  async createJournal(
    input: Omit<GlJournal, 'id' | 'created_at' | 'updated_at'>,
    lines: Omit<GlJournalLine, 'id' | 'journal_id' | 'created_at'>[]
  ): Promise<GlJournal> {
    if (!input.journal_date) throw new ValidationError('Journal date is required');
    const journal = await this.deps.repository.createJournal(input);
    for (const line of lines) {
      await this.deps.repository.createJournalLine({ ...line, journal_id: journal.id });
    }
    return journal;
  }

  async createPayment(
    input: Omit<FinancePayment, 'id' | 'created_at' | 'updated_at'>
  ): Promise<FinancePayment> {
    if (input.amount == null || input.amount <= 0)
      throw new ValidationError('Valid payment amount is required');
    return this.deps.repository.createPayment(input);
  }
}

export type { ChartOfAccountsEntry, GlJournal, GlJournalLine, FinancePayment } from './types';
export type { IFinanceRepository } from './repository';

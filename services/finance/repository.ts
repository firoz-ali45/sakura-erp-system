/**
 * Finance repository interface.
 */

import type {
  ChartOfAccountsEntry,
  GlJournal,
  GlJournalLine,
  FinancePayment,
  ApPayment,
} from './types';

export interface IFinanceRepository {
  getAccountById(id: string): Promise<ChartOfAccountsEntry | null>;
  getAccounts(filters?: { account_type?: string; is_active?: boolean }): Promise<ChartOfAccountsEntry[]>;
  createAccount(
    entry: Omit<ChartOfAccountsEntry, 'id' | 'created_at' | 'updated_at'>
  ): Promise<ChartOfAccountsEntry>;

  getJournalById(id: string): Promise<GlJournal | null>;
  getJournals(filters?: { from_date?: string; to_date?: string; status?: string }): Promise<GlJournal[]>;
  createJournal(journal: Omit<GlJournal, 'id' | 'created_at' | 'updated_at'>): Promise<GlJournal>;
  getJournalLines(journalId: string): Promise<GlJournalLine[]>;
  createJournalLine(
    line: Omit<GlJournalLine, 'id' | 'created_at'>
  ): Promise<GlJournalLine>;

  createPayment(payment: Omit<FinancePayment, 'id' | 'created_at' | 'updated_at'>): Promise<FinancePayment>;
  getApPayments(supplierId?: string): Promise<ApPayment[]>;
  createApPayment(payment: Omit<ApPayment, 'id' | 'created_at'>): Promise<ApPayment>;
}

/**
 * Finance domain types.
 */

export interface ChartOfAccountsEntry {
  id: string;
  code: string;
  name: string;
  account_type: string; // asset, liability, equity, revenue, expense
  parent_id?: string;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface GlJournal {
  id: string;
  journal_number?: string;
  journal_date: string;
  description?: string;
  status?: string;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface GlJournalLine {
  id: string;
  journal_id: string;
  account_id: string;
  debit: number;
  credit: number;
  description?: string;
  reference_type?: string;
  reference_id?: string;
  created_at?: string;
  [key: string]: unknown;
}

export interface FinancePayment {
  id: string;
  payment_type: string;
  amount: number;
  currency?: string;
  reference?: string;
  status?: string;
  paid_at?: string;
  created_at?: string;
  updated_at?: string;
  [key: string]: unknown;
}

export interface ApPayment {
  id: string;
  supplier_id?: string;
  invoice_id?: string;
  amount: number;
  payment_date: string;
  status?: string;
  created_at?: string;
  [key: string]: unknown;
}

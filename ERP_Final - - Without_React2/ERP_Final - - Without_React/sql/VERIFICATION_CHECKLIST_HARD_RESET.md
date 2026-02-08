# HARD RESET — Verification Checklist (Mandatory)

**DO NOT CLAIM COMPLETION UNTIL ALL 10 PASS.**

Run migrations in order:
1. `FINANCE_ERP_RESTRUCTURE.sql`
2. `02_FINANCE_MASTER_CURRENCY_COST.sql`
3. `03_HARD_RESET_FINANCE_RBAC.sql`
4. `04_FINANCE_MORE_ATM_BANK_SPEC.sql` — linked_bank_name, atm_number UNIQUE, account_name

---

## 1. ATM & Bank master screens exist

- [ ] **Finance → More** is visible in sidebar; clicking opens landing with **Payment Configuration** card.
- [ ] Clicking **Payment Configuration** opens sub-page with **ATM Master** and **Bank Master** sub-cards.
- [ ] **ATM Master**: list of ATMs with ATM Name, ATM #, Linked Bank, Location, Active. Add / Edit / Enable-Disable work.
- [ ] **Bank Master**: list of Banks with Bank Name, Account Name, Account #, IBAN, SWIFT Code, Active. Add / Edit / Disable work.
- [ ] **Payment Rules** (read-only): Cash on Hand, ATM / Market Purchase, Free Sample, Online Gateway, Bank Transfer (Credit must NOT appear).

---

## 2. ATM selectable in Purchasing

- [ ] Open **Finance → Purchasing (Invoices)** → open a draft PUR.
- [ ] Set **Payment Method** to **ATM / Market Purchase**.
- [ ] **ATM** dropdown appears and lists ATMs from ATM Master.
- [ ] Select an ATM, save; value persists.

---

## 3. Bank selectable only in Payments

- [ ] **Finance → Purchasing**: Payment Method dropdown does **not** show Bank Transfer or Credit. Only Cash on Hand, ATM / Market Purchase, Free Sample, Online Gateway.
- [ ] **Finance → Payments** → **New Payment**: **Bank** dropdown is present and required; lists banks from Bank Master. Manual payment cannot be submitted without selecting a bank.

---

## 4. PUR cost editable and correct

- [ ] On a **draft** PUR, **Items** section shows **Unit Cost** as editable (input).
- [ ] Unit cost defaults from PO when items are loaded (non-zero when PO has unit price).
- [ ] Changing unit cost and tabbing out recalculates line total and invoice totals (Subtotal, Tax, Grand Total).
- [ ] Changes persist after save/refresh.

---

## 5. No zero-cost bug

- [ ] PUR items do **not** show zero cost when the linked PO has a positive unit price (default from PO).
- [ ] **Free Sample** is the only case where invoice value is zero (and auto-paid).

---

## 6. Currency always SAR

- [ ] All amounts in **Finance → Purchasing**, **Payments**, **Accounts Payable**, **Finance Reports** display as **SAR**.
- [ ] **Inventory → Purchase Orders**: amounts show **SAR** (no USD).
- [ ] No currency selector in UI. DB: `purchase_orders.currency`, `purchasing_invoices.currency` = 'SAR'.

---

## 7. AP aging works correctly

- [ ] **Finance → Accounts Payable**: table has **Aging** column with buckets **0-30**, **31-60**, **61-90**, **90+**.
- [ ] Aging is derived from Due Date vs today; Open/Partial invoices show correct bucket.
- [ ] **Finance → Finance Reports**: Payables aging section shows breakdown by bucket; numbers align with AP list.

---

## 8. Manual payment updates AP

- [ ] **Finance → Payments** → create **Manual** payment: select Vendor, open invoice, Bank, amount, date, reference; submit.
- [ ] Payment appears in list with Type **MANUAL**.
- [ ] **Finance → Accounts Payable**: that invoice’s **Paid** and **Outstanding** update; status moves to Partial or Paid as appropriate.
- [ ] **Finance → Finance Reports**: Total Open Payables / Paid last 30 days reflect the payment.

---

## 9. RBAC blocks unauthorized actions

- [ ] **user_roles** and **role_permissions** are populated (run migration seed).
- [ ] Assign a user to a role that does **not** have e.g. `PUR_APPROVE` (e.g. FINANCE_USER).
- [ ] Log in as that user: **Submit for Approval** / **Approve** on PUR should be hidden or disabled (when `usePermissions().hasPermission('PUR_APPROVE')` is false).
- [ ] Admin (or user with all permissions) sees all actions.  
- [ ] Server-side: enforce permission checks in API/Supabase RLS or Edge Functions where critical.

---

## 10. Finance fully separated from Inventory

- [ ] **Sidebar**: **Inventory** has no Purchasing (Invoices), no Payment execution. **Finance** has: Purchasing (Invoices), Payments, Accounts Payable, **More** (→ Payment Configuration), Finance Reports.
- [ ] **Reports** section: no “Accounts Payable” that mixes with Finance AP (external read-only reports stay under Reports).
- [ ] No payment method or payment posting in **Inventory** module (PO/GRN only).

---

## SQL migrations reference

| File | Purpose |
|------|--------|
| `FINANCE_ERP_RESTRUCTURE.sql` | Payment method constraint, auto-payment trigger, paid_amount/paid_date |
| `02_FINANCE_MASTER_CURRENCY_COST.sql` | finance_atms, finance_banks (base), PUR cost default/recalc, currency SAR |
| `03_HARD_RESET_FINANCE_RBAC.sql` | ATM location, Bank swift_code, finance_payment_rules, finance_payments, v_accounts_payable_open, roles, permissions, role_permissions, user_roles, workflow_steps, workflow_permissions, fn_user_has_permission |
| `04_FINANCE_MORE_ATM_BANK_SPEC.sql` | finance_atms: linked_bank_name, atm_number UNIQUE; finance_banks: account_name; RLS |

---

## Vue / config reference

| Area | Path |
|------|------|
| Sidebar | `src/config/sidebarConfig.js` — Finance: Purchasing, Payments, AP, **More** (→ finance-more), Finance Reports |
| Router | `src/router/index.js` — finance-more → FinanceMore.vue; finance-more/payment-configuration → PaymentConfiguration.vue; payment-configuration redirects to same |
| Finance More | `src/views/finance/FinanceMore.vue` — Landing with Payment Configuration card |
| Payment Config | `src/views/finance/PaymentConfiguration.vue` — Payment Rules (read-only), ATM Master, Bank Master (atm_number, linked_bank_name, location; account_name, swift_code) |
| Payments | `src/views/finance/Payments.vue` — finance_payments, Type AUTO/MANUAL, Bank required for manual |
| Payment Detail | `src/views/finance/PaymentDetail.vue` — finance_payments first, fallback ap_payments |
| AP | `src/views/finance/AccountsPayable.vue` — Aging column, vendor filter, click → PUR detail |
| Finance Dashboard | `src/views/finance/FinanceDashboard.vue` — Cash position, payables aging, upcoming dues |
| RBAC | `src/composables/usePermissions.js` — hasPermission(code), load from user_roles → role_permissions → permissions |

---

**FAILURE TO MEET ANY POINT = TASK FAILED.**

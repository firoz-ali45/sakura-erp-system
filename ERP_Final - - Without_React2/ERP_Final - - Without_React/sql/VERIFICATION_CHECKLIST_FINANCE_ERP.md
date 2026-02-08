# PART 10 — Verification Checklist (Finance ERP Restructure)

Run **after** applying:
1. `sql/FINANCE_ERP_RESTRUCTURE.sql` (if not already applied)
2. `sql/02_FINANCE_MASTER_CURRENCY_COST.sql`

---

## 1. Create PR → PO → GRN → PUR

- [ ] Create a Purchase Request (Inventory → Purchase Requests).
- [ ] Convert PR to PO (PR detail → Convert to PO).
- [ ] Create GRN from PO (Inventory → GRN & Batch Control; receive against PO).
- [ ] Create Purchasing Invoice from GRN (Finance → Purchasing (Invoices); create from GRN).
- [ ] Verify document flow shows PR → PO → GRN → PUR.

---

## 2. PUR pulls PO cost automatically

- [ ] Open a PUR that was created from a GRN/PO with line items that have unit price.
- [ ] In **Items** section, **Unit Cost** and **Total Cost** are non-zero (defaulted from PO).
- [ ] If items had 0 cost, run migration/backfill or ensure PO items have `unit_price`; then reload PUR or create new PUR from GRN.

---

## 3. PUR allows cost edit

- [ ] On a **draft** PUR, in the Items table, change **Unit Cost** for one line and tab out (blur).
- [ ] **Total Cost** for that line updates; **Financial Summary** (Subtotal, Tax, Grand Total) updates after save/refresh.
- [ ] Persisted in DB (refresh page and confirm values).

---

## 4. Select ATM payment → ATM dropdown appears

- [ ] On PUR detail, set **Payment Method** to **ATM / Market Purchase**.
- [ ] **ATM** dropdown appears (required). If empty, add ATMs in Finance → Payment Configuration (ATM Master).
- [ ] Select an ATM; save; submit for approval (if validation passes).

---

## 5. Auto payment posts correctly

- [ ] On a **draft** PUR, set Payment Method to **Cash on Hand** (or ATM with ATM selected, or Free Sample, or Online Gateway with Transaction Reference).
- [ ] Submit for Approval → Approve.
- [ ] Invoice shows **Payment Status: Paid**; **Paid Amount** = Grand Total; **Outstanding** = 0.
- [ ] Finance → Payments: no manual payment needed for this invoice; auto payment created (or check `ap_payments` for matching record).

---

## 6. Bank transfer only via Finance → Payments

- [ ] Finance → Purchasing: **Payment Method** dropdown does **not** show Bank Transfer or Credit.
- [ ] Finance → Payments: create **New Payment**; select Supplier, open invoice, **Bank** (required), amount, date, reference.
- [ ] Submit; verify payment appears in list and invoice outstanding decreases.

---

## 7. Accounts Payable reflects correct outstanding

- [ ] Finance → Accounts Payable: list shows PUR invoices (Vendor, Invoice No, Date, Due Date, Amount, Paid, Outstanding, Status).
- [ ] **Open / Partial** filter shows unpaid/partial; **Paid** filter shows paid.
- [ ] **Total Outstanding** and per-invoice **Outstanding** match PUR data.
- [ ] Click row → navigates to Purchasing Document detail.

---

## 8. Currency is SAR everywhere

- [ ] Finance → Purchasing: amounts show **SAR**.
- [ ] Finance → Payments: amounts show **SAR**.
- [ ] Finance → Accounts Payable: amounts show **SAR**.
- [ ] Inventory → Purchase Orders: amounts show **SAR** (no USD).
- [ ] DB: `purchase_orders.currency`, `purchasing_invoices.currency` = 'SAR'.

---

## 9. Inventory not polluted with finance logic

- [ ] Sidebar: **Inventory** has Items, GRN & Batch Control, Inventory Count (and PR/PO/Transfer as per current design); **no** Purchasing (Invoices) under Inventory.
- [ ] **Finance** has Purchasing (Invoices), Payments, Accounts Payable, **More** (→ Payment Configuration), Finance Reports.

---

## 10. No payment logic remains in Inventory module

- [ ] Inventory → Purchase Orders / GRN: no payment method selection or payment execution.
- [ ] Payment method and payment execution only in Finance (Purchasing for auto-pay; Payments for manual bank transfer).

---

## DB migrations applied

- [ ] `FINANCE_ERP_RESTRUCTURE.sql` — payment method constraint, auto-payment trigger, paid_amount/paid_date.
- [ ] `02_FINANCE_MASTER_CURRENCY_COST.sql` — `finance_atms`, `finance_banks`, `purchasing_invoices.atm_id` / `payment_reference`, `ap_payments.bank_id` / `atm_id`, currency normalization, PUR item cost default/recalc, payment amount validation, auto-payment with atm_id/ref.

---

## Vue / UI references

- **Sidebar:** `src/config/sidebarConfig.js` — Finance: Purchasing, Payments, Accounts Payable, **More** (→ `/homeportal/finance-more`), Finance Reports.
- **Router:** `src/router/index.js` — `finance-more` → `FinanceMore.vue`; `finance-more/payment-configuration` → `PaymentConfiguration.vue`; `accounts-payable` → `AccountsPayable.vue`.
- **Finance More:** `src/views/finance/FinanceMore.vue` — Landing with Payment Configuration card → opens Payment Configuration.
- **Payment Configuration:** `src/views/finance/PaymentConfiguration.vue` — ATM Master & Bank Master CRUD (Finance → More → Payment Configuration).
- **Purchasing detail:** `src/views/inventory/PurchasingDetail.vue` — ATM dropdown (from `finance_atms`), Online Gateway ref, editable unit cost, validation (ATM required for ATM/Market Purchase).
- **Payments:** `src/views/finance/Payments.vue` — Bank dropdown (from `finance_banks`), manual Bank Transfer only; amount ≤ outstanding.
- **Accounts Payable:** `src/views/finance/AccountsPayable.vue` — From `purchasing_invoices` + `finance_payments`; filters, aging, click to detail.
- **Currency:** PO/PR/PUR/AP use SAR; no Bank Transfer or Credit in Purchasing.

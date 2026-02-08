# Verification — 9 Mandatory Points (User Spec)

**DO NOT claim completion until ALL 9 pass.**

---

1. **Finance → More visible in sidebar**
   - [ ] Sidebar shows **Finance** with child **More** (not "Payment Configuration" as direct link).
   - [ ] Clicking **More** opens `/homeportal/finance-more` (Finance More landing).

2. **Payment Configuration card exists**
   - [ ] On Finance More landing, a card **💳 Payment Configuration** is visible.
   - [ ] Subtitle: "Manage ATM & Bank accounts. Used across Purchasing & Payments."
   - [ ] Clicking the card opens Payment Configuration sub-page.

3. **ATM Master CRUD works**
   - [ ] Payment Configuration page shows **🏧 ATM Master** section (card-based list).
   - [ ] **Add ATM** opens form: ATM Name, ATM Number (required), Bank Name (linked), Location, Active.
   - [ ] Save creates/updates record in `finance_atms`; ATM Number is unique.
   - [ ] Enable/Disable (Active checkbox) works; ATM is selectable in Purchasing when active.

4. **Bank Master CRUD works**
   - [ ] Payment Configuration page shows **🏦 Bank Master** section (card-based list).
   - [ ] **Add Bank** / **Edit Bank**: Bank Name, Account Name, Account Number, IBAN, SWIFT Code, Active.
   - [ ] Disable bank without deleting history (soft disable).

5. **ATM selectable in Purchasing**
   - [ ] Finance → Purchasing (Invoices) → open a draft PUR.
   - [ ] Set Payment Method to **ATM / Market Purchase**.
   - [ ] ATM dropdown appears, populated from `finance_atms` (active only).
   - [ ] ATM Number required; Submit for Approval disabled until ATM selected.

6. **Bank selectable ONLY in Payments**
   - [ ] Finance → Purchasing: Payment Method dropdown does **not** show Bank Transfer or Credit.
   - [ ] Finance → Payments → New Payment: **Bank** dropdown is present and required; options from `finance_banks` (active).
   - [ ] Manual payment flow: Vendor → Open invoices → Select Bank → Amount, reference → Post; AP updates.

7. **Auto-payment created correctly**
   - [ ] PUR with Cash on Hand / ATM (with ATM selected) / Free Sample / Online Gateway (with ref): on Approve/Post, auto-payment record created (`finance_payments` or legacy `ap_payments` synced).
   - [ ] Invoice marked PAID; outstanding = 0.

8. **AP updates correctly**
   - [ ] AP list derived only from `purchasing_invoices` + `finance_payments`.
   - [ ] Columns: Vendor, Invoice No, Date, Due Date, Amount, Paid, Outstanding, Aging, Status (Open/Partial/Paid).
   - [ ] Manual payment from Payments reduces outstanding and updates status.

9. **UI matches enterprise ERP quality**
   - [ ] Finance → More → Payment Configuration: clear hierarchy, no config under Settings or Inventory.
   - [ ] Payment Rules (read-only) visible; Credit forbidden.
   - [ ] SAR only; no mixed currency selectors.

---

## Deliverables reference

| Item | Location |
|------|----------|
| SQL migrations | `03_HARD_RESET_FINANCE_RBAC.sql`, `04_FINANCE_MORE_ATM_BANK_SPEC.sql` |
| Sidebar | `frontend/src/config/sidebarConfig.js` — Finance children include `finance-more` |
| Router | `frontend/src/router/index.js` — `finance-more`, `finance-more/payment-configuration` |
| Finance More landing | `frontend/src/views/finance/FinanceMore.vue` |
| Payment Configuration | `frontend/src/views/finance/PaymentConfiguration.vue` — ATM Master, Bank Master |
| Purchasing ATM dropdown | `frontend/src/views/inventory/PurchasingDetail.vue` — atms from `finance_atms` |
| Payments Bank dropdown | `frontend/src/views/finance/Payments.vue` — loadBanks from `finance_banks` |
| AP | `frontend/src/views/finance/AccountsPayable.vue` — from PUR + finance_payments |

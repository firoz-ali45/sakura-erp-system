# Schema reference

This folder holds **reference** documentation and optional DDL snippets. The **authoritative** schema is defined by the SQL files in `/migrations`.

## Domain areas

| Area              | Main tables (public) |
|-------------------|------------------------|
| Inventory         | inventory_items, inventory_categories, inventory_locations, inventory_stock_ledger, inventory_batches |
| Purchasing        | purchase_requests, purchase_orders, purchase_order_items, grn_*, suppliers, pr_po_linkage |
| Finance           | chart_of_accounts, gl_journal, gl_journal_lines, finance_*, ap_payments |
| Document flow     | document_flow, doc_graph, workflow_*, pr_approval_workflow |
| Core              | users, roles, user_roles, permissions, departments, system_settings |

Create new tables or columns only via migrations in `/migrations`.

-- ============================================================
-- SAKURA ERP - ENTERPRISE DATABASE SCHEMA
-- SAP S/4HANA + Oracle ERP Architecture Style
-- PostgreSQL (Supabase) Implementation
-- ============================================================
-- 
-- Author: Sakura ERP Architecture Team
-- Version: 1.0.0
-- Date: 2026-01-24
-- 
-- This schema implements:
-- 1. Purchasing Module (Accounts Payable)
-- 2. Inventory Stock Ledger (Cost Engine)
-- 3. Document Flow (SAP-style document linking)
-- 4. General Ledger Journal (Finance Core)
-- 5. Auto-sync triggers for PO receiving
-- 6. Row-Level Security for cost hiding
-- 
-- EXECUTION ORDER:
-- 1. Tables (dependencies resolved)
-- 2. Views
-- 3. Functions
-- 4. Triggers
-- 5. Indexes
-- 6. RLS Policies
-- 7. Backfill/Migration
-- ============================================================

-- ============================================================
-- PART 1: PURCHASING MODULE TABLES
-- ============================================================

-- 1.1 Purchasing Invoice Header (AP Invoice)
-- SAP Equivalent: RBKP (Invoice Document Header)
CREATE TABLE IF NOT EXISTS purchasing_invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Reference Links
  grn_id uuid REFERENCES grn_inspections(id) ON DELETE SET NULL,
  grn_number text,
  purchase_order_id bigint REFERENCES purchase_orders(id) ON DELETE SET NULL,
  purchase_order_number text,
  
  -- Supplier Information
  supplier_id bigint REFERENCES suppliers(id) ON DELETE SET NULL,
  supplier_name text,
  
  -- Invoice Details
  invoice_number text,
  invoice_date date,
  receiving_location text,
  
  -- Financial Fields
  subtotal numeric(15,2) DEFAULT 0,
  tax_rate numeric(5,2) DEFAULT 15, -- SAR VAT 15%
  tax_amount numeric(15,2) DEFAULT 0,
  discount_amount numeric(15,2) DEFAULT 0,
  total_amount numeric(15,2) DEFAULT 0,
  grand_total numeric(15,2) DEFAULT 0,
  currency text DEFAULT 'SAR',
  
  -- Payment Terms
  payment_terms_days integer DEFAULT 30,
  due_date date,
  payment_status text DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partial', 'paid', 'overdue')),
  
  -- Workflow Status
  status text DEFAULT 'draft' CHECK (status IN ('draft', 'pending_approval', 'approved', 'posted', 'cancelled', 'void')),
  
  -- Audit Fields
  created_by text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  approved_by text,
  approved_at timestamptz,
  posted_by text,
  posted_at timestamptz,
  
  -- GL Posting Reference
  gl_journal_id uuid,
  
  -- Soft Delete
  deleted boolean DEFAULT false,
  deleted_at timestamptz,
  
  -- Notes
  notes text,
  external_reference text
);

-- 1.2 Purchasing Invoice Items (AP Invoice Lines)
-- SAP Equivalent: RSEG (Invoice Document Item)
CREATE TABLE IF NOT EXISTS purchasing_invoice_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchasing_invoice_id uuid NOT NULL REFERENCES purchasing_invoices(id) ON DELETE CASCADE,
  
  -- Item Reference
  item_id uuid REFERENCES inventory_items(id) ON DELETE SET NULL,
  item_name text,
  item_code text,
  
  -- Quantities
  quantity numeric(15,3) NOT NULL DEFAULT 0,
  unit_of_measure text,
  
  -- Pricing
  unit_cost numeric(15,4) DEFAULT 0,
  total_cost numeric(15,2) DEFAULT 0,
  tax_amount numeric(15,2) DEFAULT 0,
  
  -- Batch Reference (for traceability)
  batch_id text,
  batch_number text,
  
  -- GL Account (for posting)
  gl_account_code text,
  cost_center text,
  
  -- Metadata
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- PART 2: INVENTORY STOCK LEDGER (COST ENGINE)
-- ============================================================

-- 2.1 Stock Ledger (Material Ledger)
-- SAP Equivalent: MSEG (Material Document Segment)
-- Tracks all inventory movements with cost
CREATE TABLE IF NOT EXISTS inventory_stock_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Item Reference
  item_id uuid REFERENCES inventory_items(id) ON DELETE SET NULL,
  item_code text,
  item_name text,
  
  -- Location
  warehouse text DEFAULT 'Main Warehouse (W01)',
  storage_location text,
  
  -- Movement Data
  movement_type text NOT NULL CHECK (movement_type IN (
    'GRN', 'SALE', 'TRANSFER_IN', 'TRANSFER_OUT', 
    'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'PRODUCTION_IN', 
    'PRODUCTION_OUT', 'RETURN_IN', 'RETURN_OUT', 'SCRAP'
  )),
  qty_in numeric(15,3) DEFAULT 0,
  qty_out numeric(15,3) DEFAULT 0,
  
  -- Cost Data (SAP-style material valuation)
  unit_cost numeric(15,4) DEFAULT 0,
  total_cost numeric(15,2) DEFAULT 0,
  
  -- Running Balance (denormalized for performance)
  running_qty numeric(15,3) DEFAULT 0,
  running_value numeric(15,2) DEFAULT 0,
  
  -- Reference Document
  reference_type text, -- GRN, SO, TO, ADJ, PROD
  reference_id uuid,
  reference_number text,
  
  -- Batch Traceability (ISO 22000)
  batch_id text,
  batch_number text,
  expiry_date date,
  
  -- Posting Date (Financial)
  posting_date date DEFAULT CURRENT_DATE,
  
  -- Metadata
  created_by text,
  created_at timestamptz DEFAULT now(),
  
  -- GL Integration
  gl_journal_id uuid,
  gl_account_code text
);

-- ============================================================
-- PART 3: DOCUMENT FLOW (SAP-STYLE)
-- ============================================================

-- 3.1 Document Flow Table
-- SAP Equivalent: VBFA (Document Flow)
-- Links all related documents in procurement cycle
CREATE TABLE IF NOT EXISTS document_flow (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Source Document
  source_type text NOT NULL, -- PO, GRN, PURCHASING, SO, PRODUCTION
  source_id uuid,
  source_number text,
  
  -- Target Document
  target_type text NOT NULL,
  target_id uuid,
  target_number text,
  
  -- Flow Type
  flow_type text DEFAULT 'follows', -- follows, reverses, references
  
  -- Metadata
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- PART 4: GENERAL LEDGER (FINANCE CORE)
-- ============================================================

-- 4.1 GL Journal Header
-- SAP Equivalent: BKPF (Accounting Document Header)
CREATE TABLE IF NOT EXISTS gl_journal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Journal Info
  journal_number text,
  posting_date date NOT NULL DEFAULT CURRENT_DATE,
  document_date date DEFAULT CURRENT_DATE,
  document_type text NOT NULL CHECK (document_type IN (
    'GRN_POSTING', 'AP_INVOICE', 'AP_PAYMENT', 
    'AR_INVOICE', 'AR_RECEIPT', 'ADJUSTMENT', 'REVERSAL'
  )),
  
  -- Reference
  reference_type text,
  reference_id uuid,
  reference_number text,
  description text,
  
  -- Totals (must balance)
  total_debit numeric(15,2) DEFAULT 0,
  total_credit numeric(15,2) DEFAULT 0,
  
  -- Status
  status text DEFAULT 'draft' CHECK (status IN ('draft', 'posted', 'reversed')),
  
  -- Metadata
  created_by text,
  created_at timestamptz DEFAULT now(),
  posted_by text,
  posted_at timestamptz
);

-- 4.2 GL Journal Lines
-- SAP Equivalent: BSEG (Accounting Document Segment)
CREATE TABLE IF NOT EXISTS gl_journal_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_id uuid NOT NULL REFERENCES gl_journal(id) ON DELETE CASCADE,
  
  -- Line Number
  line_number integer DEFAULT 1,
  
  -- Account
  account_code text NOT NULL,
  account_name text,
  account_type text, -- ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
  
  -- Amounts (only one should be filled)
  debit numeric(15,2) DEFAULT 0,
  credit numeric(15,2) DEFAULT 0,
  
  -- Cost Center (optional)
  cost_center text,
  profit_center text,
  
  -- Reference
  line_description text,
  
  -- Metadata
  created_at timestamptz DEFAULT now()
);

-- 4.3 Chart of Accounts
-- SAP Equivalent: SKA1 (G/L Account Master)
CREATE TABLE IF NOT EXISTS chart_of_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  account_code text NOT NULL UNIQUE,
  account_name text NOT NULL,
  account_name_localized text,
  account_type text NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  
  -- Hierarchy
  parent_account_code text,
  level integer DEFAULT 1,
  
  -- Control
  is_active boolean DEFAULT true,
  is_header boolean DEFAULT false, -- Header accounts can't be posted to
  
  -- Default Settings
  normal_balance text DEFAULT 'DEBIT' CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
  currency text DEFAULT 'SAR',
  
  -- Metadata
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Insert default Chart of Accounts (SAP-style)
INSERT INTO chart_of_accounts (account_code, account_name, account_type, is_header) VALUES
  ('1000', 'Assets', 'ASSET', true),
  ('1100', 'Current Assets', 'ASSET', true),
  ('1110', 'Cash and Bank', 'ASSET', false),
  ('1120', 'Accounts Receivable', 'ASSET', false),
  ('1130', 'Inventory', 'ASSET', false),
  ('1131', 'Raw Materials', 'ASSET', false),
  ('1132', 'Work in Progress', 'ASSET', false),
  ('1133', 'Finished Goods', 'ASSET', false),
  ('2000', 'Liabilities', 'LIABILITY', true),
  ('2100', 'Current Liabilities', 'LIABILITY', true),
  ('2110', 'Accounts Payable', 'LIABILITY', false),
  ('2120', 'Accrued Expenses', 'LIABILITY', false),
  ('2130', 'VAT Payable', 'LIABILITY', false),
  ('3000', 'Equity', 'EQUITY', true),
  ('3100', 'Capital', 'EQUITY', false),
  ('3200', 'Retained Earnings', 'EQUITY', false),
  ('4000', 'Revenue', 'REVENUE', true),
  ('4100', 'Sales Revenue', 'REVENUE', false),
  ('5000', 'Expenses', 'EXPENSE', true),
  ('5100', 'Cost of Goods Sold', 'EXPENSE', false),
  ('5200', 'Operating Expenses', 'EXPENSE', false),
  ('5210', 'Inventory Variance', 'EXPENSE', false)
ON CONFLICT (account_code) DO NOTHING;

-- ============================================================
-- PART 5: VIEWS
-- ============================================================

-- 5.1 PO Item Receipts View (Already exists, enhanced)
DROP VIEW IF EXISTS v_po_item_receipts_enhanced CASCADE;

CREATE OR REPLACE VIEW v_po_item_receipts_enhanced AS
SELECT 
  poi.id AS po_item_id,
  poi.purchase_order_id,
  po.po_number AS purchase_order_number,
  poi.item_id,
  poi.item_name,
  poi.item_sku AS item_code,
  COALESCE(poi.quantity, 0)::NUMERIC AS ordered_qty,
  COALESCE(poi.quantity_received, 0)::NUMERIC AS received_qty,
  GREATEST(COALESCE(poi.quantity, 0) - COALESCE(poi.quantity_received, 0), 0)::NUMERIC AS remaining_qty,
  COALESCE(poi.unit_price, 0)::NUMERIC AS unit_price,
  COALESCE(poi.total_amount, 0)::NUMERIC AS line_total,
  po.status AS po_status,
  po.supplier_name
FROM purchase_order_items poi
INNER JOIN purchase_orders po ON po.id = poi.purchase_order_id
WHERE COALESCE(po.deleted, false) = false;

-- 5.2 Inventory Valuation View
CREATE OR REPLACE VIEW v_inventory_valuation AS
SELECT 
  item_id,
  item_code,
  item_name,
  warehouse,
  SUM(qty_in - qty_out) AS current_qty,
  SUM(total_cost) AS total_value,
  CASE 
    WHEN SUM(qty_in - qty_out) > 0 
    THEN SUM(total_cost) / SUM(qty_in - qty_out) 
    ELSE 0 
  END AS avg_unit_cost,
  MAX(posting_date) AS last_movement_date
FROM inventory_stock_ledger
GROUP BY item_id, item_code, item_name, warehouse
HAVING SUM(qty_in - qty_out) >= 0;

-- 5.3 Purchasing Invoice Summary View
CREATE OR REPLACE VIEW v_purchasing_summary AS
SELECT 
  pi.id,
  pi.invoice_number,
  pi.grn_number,
  pi.purchase_order_number,
  pi.supplier_name,
  pi.invoice_date,
  pi.total_amount,
  pi.tax_amount,
  pi.grand_total,
  pi.status,
  pi.payment_status,
  pi.due_date,
  pi.created_at,
  CASE 
    WHEN pi.due_date < CURRENT_DATE AND pi.payment_status = 'unpaid' 
    THEN true 
    ELSE false 
  END AS is_overdue,
  CURRENT_DATE - pi.due_date AS days_overdue
FROM purchasing_invoices pi
WHERE COALESCE(pi.deleted, false) = false;

-- ============================================================
-- PART 6: TRIGGER FUNCTIONS
-- ============================================================

-- 6.1 GRN Approval → Inventory Posting Trigger
CREATE OR REPLACE FUNCTION trg_grn_inventory_posting()
RETURNS TRIGGER AS $$
DECLARE
  v_item RECORD;
  v_warehouse TEXT;
BEGIN
  -- Only trigger on status change to 'approved' or 'passed'
  IF NEW.status IN ('approved', 'passed') AND 
     (OLD.status IS NULL OR OLD.status NOT IN ('approved', 'passed')) THEN
    
    v_warehouse := COALESCE(NEW.receiving_location, 'Main Warehouse (W01)');
    
    -- Insert stock ledger entries for each GRN item
    FOR v_item IN 
      SELECT 
        gii.item_id,
        gii.item_code,
        gii.item_name,
        gii.received_quantity,
        COALESCE(poi.unit_price, 0) AS unit_cost,
        gii.batch_number
      FROM grn_inspection_items gii
      LEFT JOIN purchase_order_items poi 
        ON poi.item_id = gii.item_id 
        AND poi.purchase_order_id = (
          SELECT id FROM purchase_orders 
          WHERE po_number = NEW.purchase_order_number
          LIMIT 1
        )
      WHERE gii.grn_inspection_id = NEW.id
        AND COALESCE(gii.received_quantity, 0) > 0
    LOOP
      INSERT INTO inventory_stock_ledger (
        item_id,
        item_code,
        item_name,
        warehouse,
        movement_type,
        qty_in,
        unit_cost,
        total_cost,
        reference_type,
        reference_id,
        reference_number,
        batch_number,
        posting_date,
        created_by
      ) VALUES (
        v_item.item_id,
        v_item.item_code,
        v_item.item_name,
        v_warehouse,
        'GRN',
        v_item.received_quantity,
        v_item.unit_cost,
        v_item.received_quantity * v_item.unit_cost,
        'GRN',
        NEW.id,
        NEW.grn_number,
        v_item.batch_number,
        CURRENT_DATE,
        NEW.approved_by_name
      );
    END LOOP;
    
    RAISE NOTICE 'Stock ledger updated for GRN: %', NEW.grn_number;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6.2 Sync PO Received Quantities Trigger
CREATE OR REPLACE FUNCTION trg_sync_po_received_from_grn()
RETURNS TRIGGER AS $$
DECLARE
  v_po_number TEXT;
  v_po_id BIGINT;
  v_total_ordered NUMERIC;
  v_total_received NUMERIC;
BEGIN
  -- Get PO number from GRN
  IF TG_OP = 'DELETE' THEN
    SELECT purchase_order_number INTO v_po_number
    FROM grn_inspections WHERE id = OLD.grn_inspection_id;
  ELSE
    SELECT purchase_order_number INTO v_po_number
    FROM grn_inspections WHERE id = NEW.grn_inspection_id;
  END IF;
  
  -- Skip if no PO linked
  IF v_po_number IS NULL OR v_po_number = '' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  
  -- Get PO ID
  SELECT id INTO v_po_id FROM purchase_orders WHERE po_number = v_po_number;
  
  IF v_po_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  
  -- Update quantity_received for each PO item
  UPDATE purchase_order_items poi
  SET quantity_received = COALESCE((
    SELECT SUM(gii.received_quantity)
    FROM grn_inspection_items gii
    INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
    WHERE gi.purchase_order_number = v_po_number
      AND gii.item_id = poi.item_id
      AND COALESCE(gi.deleted, false) = false
      AND gi.status NOT IN ('cancelled', 'rejected')
  ), 0)
  WHERE poi.purchase_order_id = v_po_id;
  
  -- Update PO header totals
  SELECT 
    COALESCE(SUM(quantity), 0),
    COALESCE(SUM(quantity_received), 0)
  INTO v_total_ordered, v_total_received
  FROM purchase_order_items
  WHERE purchase_order_id = v_po_id;
  
  UPDATE purchase_orders
  SET 
    total_received_quantity = v_total_received,
    remaining_quantity = GREATEST(v_total_ordered - v_total_received, 0),
    ordered_quantity = v_total_ordered,
    receiving_status = CASE
      WHEN v_total_received = 0 THEN 'not_received'
      WHEN v_total_received < v_total_ordered THEN 'partial'
      ELSE 'fully_received'
    END,
    status = CASE
      WHEN v_total_received >= v_total_ordered AND status = 'approved' THEN 'fully_received'
      WHEN v_total_received > 0 AND v_total_received < v_total_ordered AND status = 'approved' THEN 'partially_received'
      ELSE status
    END,
    updated_at = now()
  WHERE id = v_po_id;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 6.3 Auto-generate Invoice Number
CREATE OR REPLACE FUNCTION trg_generate_invoice_number()
RETURNS TRIGGER AS $$
DECLARE
  v_year TEXT;
  v_sequence INTEGER;
  v_invoice_number TEXT;
BEGIN
  IF NEW.invoice_number IS NULL OR NEW.invoice_number = '' THEN
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(
      CAST(SUBSTRING(invoice_number FROM 'INV-\d{4}-(\d+)') AS INTEGER)
    ), 0) + 1
    INTO v_sequence
    FROM purchasing_invoices
    WHERE invoice_number LIKE 'INV-' || v_year || '-%';
    
    NEW.invoice_number := 'INV-' || v_year || '-' || LPAD(v_sequence::TEXT, 6, '0');
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6.4 Calculate Invoice Totals
CREATE OR REPLACE FUNCTION trg_calculate_invoice_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_subtotal NUMERIC;
  v_tax_amount NUMERIC;
BEGIN
  -- Calculate subtotal from items
  SELECT COALESCE(SUM(total_cost), 0) INTO v_subtotal
  FROM purchasing_invoice_items
  WHERE purchasing_invoice_id = NEW.id;
  
  -- Calculate tax
  v_tax_amount := v_subtotal * COALESCE(NEW.tax_rate, 15) / 100;
  
  -- Update totals
  NEW.subtotal := v_subtotal;
  NEW.tax_amount := v_tax_amount;
  NEW.total_amount := v_subtotal;
  NEW.grand_total := v_subtotal + v_tax_amount - COALESCE(NEW.discount_amount, 0);
  
  -- Set due date if not set
  IF NEW.due_date IS NULL AND NEW.invoice_date IS NOT NULL THEN
    NEW.due_date := NEW.invoice_date + COALESCE(NEW.payment_terms_days, 30);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- PART 7: CREATE TRIGGERS
-- ============================================================

-- Drop existing triggers first
DROP TRIGGER IF EXISTS trg_grn_post_inventory ON grn_inspections;
DROP TRIGGER IF EXISTS trg_grn_item_sync_po ON grn_inspection_items;
DROP TRIGGER IF EXISTS trg_purchasing_invoice_number ON purchasing_invoices;
DROP TRIGGER IF EXISTS trg_purchasing_calc_totals ON purchasing_invoices;

-- Create triggers
CREATE TRIGGER trg_grn_post_inventory
  AFTER UPDATE OF status ON grn_inspections
  FOR EACH ROW
  EXECUTE FUNCTION trg_grn_inventory_posting();

CREATE TRIGGER trg_grn_item_sync_po
  AFTER INSERT OR UPDATE OR DELETE ON grn_inspection_items
  FOR EACH ROW
  EXECUTE FUNCTION trg_sync_po_received_from_grn();

CREATE TRIGGER trg_purchasing_invoice_number
  BEFORE INSERT ON purchasing_invoices
  FOR EACH ROW
  EXECUTE FUNCTION trg_generate_invoice_number();

CREATE TRIGGER trg_purchasing_calc_totals
  BEFORE INSERT OR UPDATE ON purchasing_invoices
  FOR EACH ROW
  EXECUTE FUNCTION trg_calculate_invoice_totals();

-- ============================================================
-- PART 8: INDEXES (PERFORMANCE)
-- ============================================================

-- GRN Indexes
CREATE INDEX IF NOT EXISTS idx_grn_items_grn_id ON grn_inspection_items(grn_inspection_id);
CREATE INDEX IF NOT EXISTS idx_grn_items_item_id ON grn_inspection_items(item_id);
CREATE INDEX IF NOT EXISTS idx_grn_items_po_id ON grn_inspection_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_grn_po_number ON grn_inspections(purchase_order_number);
CREATE INDEX IF NOT EXISTS idx_grn_supplier_id ON grn_inspections(supplier_id);
CREATE INDEX IF NOT EXISTS idx_grn_status ON grn_inspections(status);

-- PO Indexes
CREATE INDEX IF NOT EXISTS idx_po_items_po_id ON purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_po_items_item_id ON purchase_order_items(item_id);
CREATE INDEX IF NOT EXISTS idx_po_supplier_id ON purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_po_status ON purchase_orders(status);

-- Purchasing Indexes
CREATE INDEX IF NOT EXISTS idx_purchasing_grn_id ON purchasing_invoices(grn_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_po_id ON purchasing_invoices(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_supplier ON purchasing_invoices(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchasing_status ON purchasing_invoices(status);
CREATE INDEX IF NOT EXISTS idx_purchasing_date ON purchasing_invoices(invoice_date);

-- Stock Ledger Indexes
CREATE INDEX IF NOT EXISTS idx_stock_ledger_item_id ON inventory_stock_ledger(item_id);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_warehouse ON inventory_stock_ledger(warehouse);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_ref ON inventory_stock_ledger(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_stock_ledger_date ON inventory_stock_ledger(posting_date);

-- Document Flow Indexes
CREATE INDEX IF NOT EXISTS idx_doc_flow_source ON document_flow(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_doc_flow_target ON document_flow(target_type, target_id);

-- GL Indexes
CREATE INDEX IF NOT EXISTS idx_gl_journal_date ON gl_journal(posting_date);
CREATE INDEX IF NOT EXISTS idx_gl_journal_ref ON gl_journal(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_gl_lines_journal ON gl_journal_lines(journal_id);
CREATE INDEX IF NOT EXISTS idx_gl_lines_account ON gl_journal_lines(account_code);

-- ============================================================
-- PART 9: ROW LEVEL SECURITY (COST HIDING)
-- ============================================================

-- Enable RLS on stock ledger (hide costs from non-finance users)
ALTER TABLE inventory_stock_ledger ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all authenticated users to see stock movements (but hide cost)
-- Note: This requires a view to hide the cost columns instead
-- For now, we'll create a non-cost view for inventory users

CREATE OR REPLACE VIEW v_inventory_movements AS
SELECT 
  id,
  item_id,
  item_code,
  item_name,
  warehouse,
  storage_location,
  movement_type,
  qty_in,
  qty_out,
  -- Cost columns hidden
  reference_type,
  reference_id,
  reference_number,
  batch_id,
  batch_number,
  expiry_date,
  posting_date,
  created_at
FROM inventory_stock_ledger;

-- Grant access to views
GRANT SELECT ON v_po_item_receipts_enhanced TO authenticated;
GRANT SELECT ON v_po_item_receipts_enhanced TO anon;
GRANT SELECT ON v_inventory_valuation TO authenticated;
GRANT SELECT ON v_purchasing_summary TO authenticated;
GRANT SELECT ON v_inventory_movements TO authenticated;

-- ============================================================
-- PART 10: BACKFILL / MIGRATION SCRIPT
-- ============================================================

-- Backfill purchase_order_items.quantity_received from existing GRNs
UPDATE purchase_order_items poi
SET quantity_received = COALESCE((
  SELECT SUM(gii.received_quantity)
  FROM grn_inspection_items gii
  INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
  WHERE gi.purchase_order_number = (
    SELECT po_number FROM purchase_orders WHERE id = poi.purchase_order_id
  )
  AND gii.item_id = poi.item_id
  AND COALESCE(gi.deleted, false) = false
  AND gi.status NOT IN ('cancelled', 'rejected')
), 0)
WHERE EXISTS (
  SELECT 1 FROM grn_inspection_items gii
  INNER JOIN grn_inspections gi ON gi.id = gii.grn_inspection_id
  WHERE gi.purchase_order_number = (
    SELECT po_number FROM purchase_orders WHERE id = poi.purchase_order_id
  )
  AND gii.item_id = poi.item_id
);

-- Update PO header receiving totals
UPDATE purchase_orders po
SET 
  total_received_quantity = COALESCE((
    SELECT SUM(quantity_received) FROM purchase_order_items WHERE purchase_order_id = po.id
  ), 0),
  remaining_quantity = COALESCE(ordered_quantity, 0) - COALESCE((
    SELECT SUM(quantity_received) FROM purchase_order_items WHERE purchase_order_id = po.id
  ), 0)
WHERE EXISTS (
  SELECT 1 FROM purchase_order_items WHERE purchase_order_id = po.id AND quantity_received > 0
);

-- ============================================================
-- COMPLETION NOTICE
-- ============================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '✅ SAKURA ERP ENTERPRISE SCHEMA INSTALLED SUCCESSFULLY';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'TABLES CREATED:';
  RAISE NOTICE '  • purchasing_invoices (AP Invoice Header)';
  RAISE NOTICE '  • purchasing_invoice_items (AP Invoice Lines)';
  RAISE NOTICE '  • inventory_stock_ledger (Material Ledger)';
  RAISE NOTICE '  • document_flow (SAP-style Document Linking)';
  RAISE NOTICE '  • gl_journal (General Ledger Header)';
  RAISE NOTICE '  • gl_journal_lines (GL Lines)';
  RAISE NOTICE '  • chart_of_accounts (CoA Master)';
  RAISE NOTICE '';
  RAISE NOTICE 'TRIGGERS ACTIVATED:';
  RAISE NOTICE '  • GRN Approval → Stock Ledger Posting';
  RAISE NOTICE '  • GRN Items → PO Received Qty Sync';
  RAISE NOTICE '  • Purchasing Invoice Number Auto-Generation';
  RAISE NOTICE '  • Purchasing Totals Auto-Calculation';
  RAISE NOTICE '';
  RAISE NOTICE 'VIEWS CREATED:';
  RAISE NOTICE '  • v_po_item_receipts_enhanced';
  RAISE NOTICE '  • v_inventory_valuation';
  RAISE NOTICE '  • v_purchasing_summary';
  RAISE NOTICE '  • v_inventory_movements (cost-hidden)';
  RAISE NOTICE '';
  RAISE NOTICE 'NEXT STEPS:';
  RAISE NOTICE '  1. Run this script in Supabase SQL Editor';
  RAISE NOTICE '  2. Refresh your application';
  RAISE NOTICE '  3. Test: Create GRN → Approve → Create Purchasing';
  RAISE NOTICE '';
END $$;

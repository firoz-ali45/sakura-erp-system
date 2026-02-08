-- ============================================================================
-- SAKURA ERP - PURCHASE REQUEST (PR) CORE TABLES
-- SAP MM Architecture Compliant
-- ============================================================================
-- File: PR_CORE_TABLES.sql
-- Purpose: Define core PR header and line item tables following SAP EBAN/EBKN model
-- Author: Enterprise ERP Team
-- Date: 2026-01-25
-- Version: 1.0.0
-- ============================================================================

-- ============================================================================
-- TABLE: purchase_requests (SAP EBAN Header Equivalent)
-- Description: Purchase Request Header - Stores PR master data
-- SAP Equivalent: EBAN (Purchase Requisition)
-- ============================================================================

CREATE TABLE IF NOT EXISTS purchase_requests (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- PR Identification (SAP BANFN equivalent)
    pr_number TEXT UNIQUE NOT NULL,
    
    -- Requester Information (SAP AFNAM equivalent)
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    requester_name TEXT NOT NULL,
    
    -- Organizational Data (SAP Org Assignment)
    department TEXT NOT NULL,
    cost_center TEXT,
    plant_code TEXT DEFAULT 'P001',
    purchasing_group TEXT DEFAULT 'PG01',
    company_code TEXT DEFAULT 'CC01',
    
    -- Date Management
    business_date DATE NOT NULL DEFAULT CURRENT_DATE,
    required_date DATE NOT NULL,
    validity_start DATE DEFAULT CURRENT_DATE,
    validity_end DATE,
    
    -- Priority (SAP FRGKZ equivalent)
    priority TEXT NOT NULL DEFAULT 'normal' 
        CHECK (priority IN ('low', 'normal', 'high', 'urgent', 'critical')),
    
    -- Status Workflow (SAP Status Management)
    status TEXT NOT NULL DEFAULT 'draft' 
        CHECK (status IN (
            'draft',           -- Initial creation, editable
            'submitted',       -- Sent for approval
            'under_review',    -- Being reviewed by approver
            'approved',        -- Approved, ready for PO conversion
            'rejected',        -- Rejected by approver
            'partially_ordered', -- Some items converted to PO
            'fully_ordered',   -- All items converted to PO
            'closed',          -- Administratively closed
            'cancelled'        -- Cancelled before processing
        )),
    
    -- Approval Workflow
    approval_level INT DEFAULT 1,
    current_approver_id UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    -- Financial Estimates (Non-posting, estimate only)
    currency TEXT DEFAULT 'SAR',
    estimated_total_value NUMERIC(18, 4) DEFAULT 0.00,
    budget_code TEXT,
    budget_available BOOLEAN DEFAULT TRUE,
    
    -- Document Control
    external_reference TEXT,
    source_system TEXT DEFAULT 'SAKURA_ERP',
    document_type TEXT DEFAULT 'NB' CHECK (document_type IN ('NB', 'RV', 'SV', 'FO', 'UB')),
    -- NB = Standard PR, RV = Return, SV = Service, FO = Framework Order, UB = Stock Transport
    
    -- Notes and Attachments
    notes TEXT,
    internal_memo TEXT,
    attachments JSONB DEFAULT '[]'::jsonb,
    
    -- SAP Release Strategy Fields
    release_group TEXT,
    release_strategy TEXT,
    release_indicator TEXT DEFAULT 'X',
    
    -- Audit Trail
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_by UUID REFERENCES users(id),
    
    -- Soft Delete
    deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES users(id),
    
    -- Version Control (Optimistic Locking)
    version INT DEFAULT 1,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

-- ============================================================================
-- TABLE: purchase_request_items (SAP EBAN Line Item Equivalent)
-- Description: Purchase Request Line Items - Individual requested items
-- SAP Equivalent: EBAN Item Level / EBKN (Account Assignment)
-- ============================================================================

CREATE TABLE IF NOT EXISTS purchase_request_items (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Parent Reference
    pr_id UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
    
    -- Item Identification (SAP BNFPO equivalent)
    item_number INT NOT NULL,
    
    -- Material Reference (SAP MATNR equivalent)
    item_id UUID REFERENCES inventory_items(id),
    item_code TEXT,
    item_name TEXT NOT NULL,
    item_description TEXT,
    material_group TEXT,
    
    -- Quantity and UoM (SAP MENGE/MEINS)
    quantity NUMERIC(18, 4) NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL DEFAULT 'EA',
    quantity_ordered NUMERIC(18, 4) DEFAULT 0,
    quantity_remaining NUMERIC(18, 4) GENERATED ALWAYS AS (quantity - quantity_ordered) STORED,
    
    -- Pricing (Estimated - SAP PREIS)
    estimated_price NUMERIC(18, 4) DEFAULT 0.00,
    estimated_total NUMERIC(18, 4) GENERATED ALWAYS AS (quantity * estimated_price) STORED,
    price_unit INT DEFAULT 1,
    currency TEXT DEFAULT 'SAR',
    
    -- Preferred Supplier (Optional suggestion)
    suggested_supplier_id BIGINT REFERENCES suppliers(id),
    suggested_supplier_name TEXT,
    fixed_supplier BOOLEAN DEFAULT FALSE,
    
    -- Delivery Information
    delivery_address TEXT,
    required_date DATE,
    delivery_priority TEXT DEFAULT 'normal',
    
    -- Item Status (Separate from header status)
    status TEXT NOT NULL DEFAULT 'open' 
        CHECK (status IN (
            'open',           -- Not yet processed
            'partially_converted', -- Partially converted to PO
            'converted_to_po', -- Fully converted to PO
            'cancelled',      -- Item cancelled
            'blocked'         -- Blocked for processing
        )),
    
    -- PO Reference (Populated after conversion)
    po_id BIGINT REFERENCES purchase_orders(id),
    po_number TEXT,
    po_item_number INT,
    conversion_date TIMESTAMPTZ,
    converted_by UUID REFERENCES users(id),
    
    -- Account Assignment (SAP EBKN equivalent)
    account_assignment_category TEXT DEFAULT 'K',
    gl_account TEXT,
    cost_center TEXT,
    wbs_element TEXT,
    asset_number TEXT,
    order_number TEXT,
    
    -- Quality and Specifications
    specifications JSONB DEFAULT '{}'::jsonb,
    quality_requirements TEXT,
    inspection_required BOOLEAN DEFAULT FALSE,
    
    -- Notes
    item_notes TEXT,
    internal_note TEXT,
    
    -- Lock Indicator (Prevent edits after conversion)
    is_locked BOOLEAN DEFAULT FALSE,
    locked_at TIMESTAMPTZ,
    locked_by UUID REFERENCES users(id),
    lock_reason TEXT,
    
    -- Audit Trail
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_by UUID REFERENCES users(id),
    
    -- Soft Delete
    deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Unique constraint for item number within PR
    CONSTRAINT unique_pr_item_number UNIQUE (pr_id, item_number)
);

-- ============================================================================
-- TABLE: pr_number_sequence
-- Description: Sequence counter for PR number generation (yearly reset)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_number_sequence (
    id SERIAL PRIMARY KEY,
    fiscal_year INT NOT NULL UNIQUE,
    last_number INT NOT NULL DEFAULT 0,
    prefix TEXT DEFAULT 'PR',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initialize current year sequence
INSERT INTO pr_number_sequence (fiscal_year, last_number)
VALUES (EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0)
ON CONFLICT (fiscal_year) DO NOTHING;

-- ============================================================================
-- TABLE: pr_status_history
-- Description: Audit trail for status changes (SAP CDHDR/CDPOS equivalent)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_id UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
    
    -- Status Change Details
    previous_status TEXT,
    new_status TEXT NOT NULL,
    
    -- Change Information
    changed_by UUID REFERENCES users(id),
    changed_by_name TEXT,
    change_reason TEXT,
    change_date TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Additional Context
    ip_address INET,
    user_agent TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

-- ============================================================================
-- TABLE: pr_approval_workflow
-- Description: Multi-level approval workflow configuration and history
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_approval_workflow (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_id UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
    
    -- Approval Level
    approval_level INT NOT NULL,
    approval_step TEXT NOT NULL,
    
    -- Approver Information
    approver_id UUID REFERENCES users(id),
    approver_role TEXT,
    approver_department TEXT,
    
    -- Approval Decision
    decision TEXT CHECK (decision IN ('pending', 'approved', 'rejected', 'delegated', 'escalated')),
    decision_date TIMESTAMPTZ,
    decision_notes TEXT,
    
    -- Delegation
    delegated_to UUID REFERENCES users(id),
    delegation_reason TEXT,
    
    -- Threshold Based Approval
    threshold_amount NUMERIC(18, 4),
    threshold_currency TEXT DEFAULT 'SAR',
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    due_date TIMESTAMPTZ,
    
    -- Unique constraint for approval level per PR
    CONSTRAINT unique_pr_approval_level UNIQUE (pr_id, approval_level)
);

-- ============================================================================
-- TABLE: pr_comments
-- Description: Comments and collaboration on PR documents
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_id UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
    pr_item_id UUID REFERENCES purchase_request_items(id) ON DELETE CASCADE,
    
    -- Comment Content
    comment_text TEXT NOT NULL,
    comment_type TEXT DEFAULT 'general' CHECK (comment_type IN ('general', 'approval', 'rejection', 'query', 'response', 'internal')),
    
    -- Author
    author_id UUID REFERENCES users(id),
    author_name TEXT,
    
    -- Visibility
    is_internal BOOLEAN DEFAULT FALSE,
    
    -- Threading
    parent_comment_id UUID REFERENCES pr_comments(id),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    -- Soft Delete
    deleted BOOLEAN DEFAULT FALSE
);

-- ============================================================================
-- TABLE: pr_attachments
-- Description: Document attachments for PR (SAP GOS equivalent)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pr_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pr_id UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
    pr_item_id UUID REFERENCES purchase_request_items(id) ON DELETE CASCADE,
    
    -- File Information
    file_name TEXT NOT NULL,
    file_type TEXT,
    file_size INT,
    file_path TEXT,
    storage_bucket TEXT DEFAULT 'pr-attachments',
    
    -- Classification
    attachment_type TEXT DEFAULT 'general' CHECK (attachment_type IN ('general', 'specification', 'quotation', 'approval', 'contract', 'image')),
    description TEXT,
    
    -- Upload Information
    uploaded_by UUID REFERENCES users(id),
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

-- ============================================================================
-- COMMENTS ON TABLES
-- ============================================================================

COMMENT ON TABLE purchase_requests IS 'SAP MM EBAN equivalent - Purchase Request Header containing organizational and workflow data';
COMMENT ON TABLE purchase_request_items IS 'SAP MM EBAN/EBKN equivalent - Purchase Request Line Items with material and account assignment';
COMMENT ON TABLE pr_number_sequence IS 'Atomic counter for yearly PR number generation following enterprise numbering standards';
COMMENT ON TABLE pr_status_history IS 'SAP CDHDR/CDPOS equivalent - Complete audit trail of status transitions';
COMMENT ON TABLE pr_approval_workflow IS 'Multi-level approval workflow with delegation and escalation support';
COMMENT ON TABLE pr_comments IS 'Collaboration and communication thread for PR documents';
COMMENT ON TABLE pr_attachments IS 'SAP GOS equivalent - Document and file attachments';

-- ============================================================================
-- COLUMN COMMENTS - purchase_requests
-- ============================================================================

COMMENT ON COLUMN purchase_requests.pr_number IS 'Unique PR identifier in format PR-YYYY-NNNNNN';
COMMENT ON COLUMN purchase_requests.department IS 'Requesting department/organizational unit';
COMMENT ON COLUMN purchase_requests.cost_center IS 'Default cost center for account assignment';
COMMENT ON COLUMN purchase_requests.status IS 'Current workflow status - draft/submitted/approved/rejected/partially_ordered/closed';
COMMENT ON COLUMN purchase_requests.estimated_total_value IS 'Estimated total value - FOR BUDGETING ONLY, does not affect finance';
COMMENT ON COLUMN purchase_requests.document_type IS 'PR document type: NB=Standard, RV=Return, SV=Service, FO=Framework, UB=Transfer';

-- ============================================================================
-- COLUMN COMMENTS - purchase_request_items
-- ============================================================================

COMMENT ON COLUMN purchase_request_items.quantity_ordered IS 'Quantity already converted to Purchase Orders';
COMMENT ON COLUMN purchase_request_items.quantity_remaining IS 'Remaining quantity available for PO conversion';
COMMENT ON COLUMN purchase_request_items.estimated_price IS 'Estimated unit price - FOR REFERENCE ONLY, PO price may differ';
COMMENT ON COLUMN purchase_request_items.is_locked IS 'Prevents modification after PO conversion';
COMMENT ON COLUMN purchase_request_items.account_assignment_category IS 'SAP account assignment: K=Cost Center, A=Asset, P=Project';

-- ============================================================================
-- END OF PR_CORE_TABLES.sql
-- ============================================================================

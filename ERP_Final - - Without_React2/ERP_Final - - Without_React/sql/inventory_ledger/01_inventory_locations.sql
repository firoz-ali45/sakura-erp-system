-- ============================================================
-- MODULE 1: INVENTORY LOCATIONS (DESTINATION ENGINE)
-- SAP-style: Storage Location / Plant; Foodics/Oracle: Warehouse/Branch
-- PO & GRN default destination = WAREHOUSE. BRANCH cannot be PO destination.
-- ============================================================

-- Location type: WAREHOUSE (purchasing + production + transfer source)
--               BRANCH (POS, sales only, cannot create PO)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_location_type') THEN
    CREATE TYPE inventory_location_type AS ENUM ('WAREHOUSE', 'BRANCH');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS inventory_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  location_code text NOT NULL,
  location_name text NOT NULL,
  location_type inventory_location_type NOT NULL,
  allow_grn boolean NOT NULL DEFAULT true,
  allow_transfer_out boolean NOT NULL DEFAULT true,
  allow_pos_sale boolean NOT NULL DEFAULT false,
  allow_production boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_inventory_locations_code UNIQUE (location_code)
);

COMMENT ON TABLE inventory_locations IS 'Destination engine: WAREHOUSE = non-POS, PO/GRN/production/transfer; BRANCH = POS, sales only, receives via transfer or GRN if allowed.';
COMMENT ON COLUMN inventory_locations.allow_grn IS 'Location can receive GRN. PO & GRN default destination = WAREHOUSE.';
COMMENT ON COLUMN inventory_locations.allow_transfer_out IS 'Stock can be transferred out to other locations.';
COMMENT ON COLUMN inventory_locations.allow_pos_sale IS 'Branch: POS sales allowed. Warehouse: typically false.';
COMMENT ON COLUMN inventory_locations.allow_production IS 'Warehouse: can receive production output. Branch: cannot.';

CREATE INDEX IF NOT EXISTS idx_inventory_locations_type ON inventory_locations(location_type);
CREATE INDEX IF NOT EXISTS idx_inventory_locations_active ON inventory_locations(is_active);

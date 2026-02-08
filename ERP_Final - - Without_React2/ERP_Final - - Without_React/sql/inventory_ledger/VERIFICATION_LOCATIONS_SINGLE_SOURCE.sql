-- ============================================================
-- VERIFICATION: inventory_locations is the ONLY source for dropdowns
-- Run in Supabase. No ghost locations = all UI options come from here.
-- ============================================================

-- 1) All active locations (what Reports / filters use)
SELECT id, location_code, location_name, location_type, is_active,
       allow_grn, allow_transfer_out, allow_pos_sale, allow_production
FROM inventory_locations
WHERE is_active = true
ORDER BY location_name;

-- 2) PO/GRN destination options (allow_grn = true)
SELECT location_code, location_name,
       location_name || ' (' || location_code || ')' AS display_value
FROM inventory_locations
WHERE is_active = true AND allow_grn = true
ORDER BY location_name;

-- 3) Transfer source options (allow_transfer_out = true)
SELECT location_code, location_name
FROM inventory_locations
WHERE is_active = true AND allow_transfer_out = true
ORDER BY location_name;

-- 4) Count: must match what UI shows (no extra ghost rows)
SELECT COUNT(*) AS total_active,
       COUNT(*) FILTER (WHERE allow_grn) AS for_po_grn,
       COUNT(*) FILTER (WHERE allow_transfer_out) AS for_transfer_source
FROM inventory_locations
WHERE is_active = true;

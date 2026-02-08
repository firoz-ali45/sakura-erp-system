-- 02_DOCUMENT_FLOW_RECURSIVE_VIEW.sql
-- FLATTENED GLOBAL VIEW (Cache/Log Based)
-- This view provides a quick way to see flow history without expensive recursion for lists.
-- Note: Real-time traversal uses fn_recursive_document_graph.
DROP VIEW IF EXISTS v_document_flow_recursive;
CREATE OR REPLACE VIEW v_document_flow_recursive AS
SELECT df.source_type,
    df.source_id,
    df.source_number,
    df.target_type,
    df.target_id,
    df.target_number,
    df.flow_type,
    df.created_at,
    -- Human Friendly Description
    CONCAT(
        df.source_type,
        ' ',
        df.source_number,
        ' -> ',
        df.target_type,
        ' ',
        df.target_number,
        ' (',
        df.flow_type,
        ')'
    ) as description
FROM document_flow df
ORDER BY df.created_at DESC;
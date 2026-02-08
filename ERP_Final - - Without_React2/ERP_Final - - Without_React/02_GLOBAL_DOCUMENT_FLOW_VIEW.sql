-- 02_GLOBAL_DOCUMENT_FLOW_VIEW.sql
-- FLATTENED GLOBAL VIEW FOR UI QUERIES
-- This view flattens the document_flow table for easy listing of all events.
-- Note: The TRUTH is in fn_trace_document_graph, but this view helps with activity logs.
DROP VIEW IF EXISTS v_document_flow_global;
CREATE OR REPLACE VIEW v_document_flow_global AS
SELECT df.source_type,
    df.source_id,
    df.source_number,
    df.target_type,
    df.target_id,
    df.target_number,
    df.flow_type,
    df.created_at,
    -- Add human friendly description
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
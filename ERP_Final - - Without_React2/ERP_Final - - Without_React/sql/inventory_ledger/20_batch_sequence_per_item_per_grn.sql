-- ============================================================
-- 20: BATCH SEQUENCE PER ITEM PER GRN
-- Same item + same GRN + multiple batches → 001, 002, 003...
-- Concurrency-safe. No UI/view change. Function + sequence table only.
-- ============================================================

-- Sequence table: (grn_id, item_id) so sequence increments per item per GRN
DROP TABLE IF EXISTS grn_batch_sequence CASCADE;
CREATE TABLE grn_batch_sequence (
  grn_id    uuid NOT NULL,
  item_id   uuid NOT NULL,
  last_seq  integer NOT NULL DEFAULT 0,
  PRIMARY KEY (grn_id, item_id)
);
COMMENT ON TABLE grn_batch_sequence IS 'Per (grn_id, item_id) sequence for batch_number suffix.';

-- Function: BATCH-{grn_number}-{YYYYMMDD}-{SEQ} — business-only, no UUID/random fragment. Expiry kept.
CREATE OR REPLACE FUNCTION fn_generate_batch_number_from_grn(p_grn_id uuid, p_item_id uuid DEFAULT NULL, p_expiry_date date DEFAULT NULL)
RETURNS text AS $$
DECLARE
  v_grn_number text;
  v_seq        integer;
  v_key_id     uuid;
  v_expiry_str text;
BEGIN
  IF p_grn_id IS NULL THEN
    RETURN 'BATCH-UNKNOWN-' || to_char(COALESCE(p_expiry_date, CURRENT_DATE), 'YYYYMMDD') || '-' || lpad((floor(random() * 1000))::text, 3, '0');
  END IF;

  v_key_id := COALESCE(p_item_id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_expiry_str := to_char(COALESCE(p_expiry_date, CURRENT_DATE), 'YYYYMMDD');

  SELECT COALESCE(NULLIF(TRIM(gi.grn_number), ''), 'GRN')
    INTO v_grn_number
  FROM grn_inspections gi
  WHERE gi.id = p_grn_id;

  v_grn_number := regexp_replace(COALESCE(v_grn_number, 'GRN'), '[^A-Za-z0-9-]', '', 'g');
  v_grn_number := COALESCE(NULLIF(v_grn_number, ''), 'GRN');

  -- Concurrency-safe: next sequence per (grn_id, item_id)
  INSERT INTO grn_batch_sequence (grn_id, item_id, last_seq)
  VALUES (p_grn_id, v_key_id, 1)
  ON CONFLICT (grn_id, item_id) DO UPDATE SET last_seq = grn_batch_sequence.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN 'BATCH-' || v_grn_number || '-' || v_expiry_str || '-' || lpad(v_seq::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Trigger: pass item_id and expiry_date so format is BATCH-{GRN}-{YYYYMMDD}-{SEQ}
CREATE OR REPLACE FUNCTION trg_set_batch_number_from_grn()
RETURNS trigger AS $$
BEGIN
  IF NEW.batch_number IS NULL OR TRIM(NEW.batch_number) = '' THEN
    NEW.batch_number := fn_generate_batch_number_from_grn(NEW.received_from_grn_id, NEW.item_id, NEW.expiry_date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_batch_number_from_grn ON inventory_batches;
CREATE TRIGGER trg_set_batch_number_from_grn
  BEFORE INSERT ON inventory_batches
  FOR EACH ROW
  EXECUTE FUNCTION trg_set_batch_number_from_grn();

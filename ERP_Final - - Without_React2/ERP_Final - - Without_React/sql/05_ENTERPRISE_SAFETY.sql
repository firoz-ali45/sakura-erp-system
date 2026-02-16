-- ============================================================================
-- ENTERPRISE SAFETY: Transaction Locking, Audit Trail, Double-Submit Prevention
-- ============================================================================

-- ============================================================================
-- PART 1: IDEMPOTENCY KEYS (Double-submit prevention at DB level)
-- ============================================================================

CREATE TABLE IF NOT EXISTS idempotency_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL UNIQUE,
  entity_type text NOT NULL,
  entity_id text,
  user_id text,
  request_hash text,
  response_snapshot jsonb,
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_key ON idempotency_keys(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires ON idempotency_keys(expires_at);

-- Cleanup expired keys (run periodically or via cron)
CREATE OR REPLACE FUNCTION fn_cleanup_expired_idempotency_keys()
RETURNS void AS $$
BEGIN
  DELETE FROM idempotency_keys WHERE expires_at < now();
END;
$$ LANGUAGE plpgsql;

-- Check idempotency: returns existing response if key was used, else null
CREATE OR REPLACE FUNCTION fn_check_idempotency(p_key text, p_entity_type text, p_user_id text)
RETURNS jsonb AS $$
DECLARE
  v_row idempotency_keys%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM idempotency_keys
  WHERE idempotency_key = p_key AND expires_at > now();
  IF FOUND THEN
    RETURN v_row.response_snapshot;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Store idempotency result (call after successful mutation)
CREATE OR REPLACE FUNCTION fn_store_idempotency(p_key text, p_entity_type text, p_entity_id text, p_user_id text, p_response jsonb)
RETURNS void AS $$
BEGIN
  INSERT INTO idempotency_keys (idempotency_key, entity_type, entity_id, user_id, response_snapshot, expires_at)
  VALUES (p_key, p_entity_type, COALESCE(p_entity_id, ''), COALESCE(p_user_id, ''), p_response, now() + interval '24 hours')
  ON CONFLICT (idempotency_key) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 2: AUDIT_LOGS TABLE (if not exists)
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  old_values jsonb,
  new_values jsonb,
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all audit_logs" ON audit_logs;
CREATE POLICY "Allow all audit_logs" ON audit_logs FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- PART 3: GENERIC AUDIT TRIGGER (SAP CDHDR/CDPOS style)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id text;
  v_old_json jsonb;
  v_new_json jsonb;
  v_action text;
BEGIN
  v_user_id := COALESCE(current_setting('app.current_user_id', true), '');
  v_action := TG_OP;

  IF TG_OP = 'DELETE' THEN
    v_old_json := to_jsonb(OLD);
    v_new_json := NULL;
  ELSIF TG_OP = 'UPDATE' THEN
    v_old_json := to_jsonb(OLD);
    v_new_json := to_jsonb(NEW);
  ELSE
    v_old_json := NULL;
    v_new_json := to_jsonb(NEW);
  END IF;

  INSERT INTO audit_logs (user_id, action, entity_type, entity_id, old_values, new_values)
  VALUES (
    NULLIF(trim(v_user_id), ''),
    v_action,
    TG_TABLE_NAME,
    COALESCE(
      (CASE WHEN TG_OP = 'DELETE' THEN (OLD).id ELSE (NEW).id END)::text,
      ''
    ),
    v_old_json,
    v_new_json
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit trigger to critical tables (optional - enable per table)
-- Example: CREATE TRIGGER trg_audit_purchase_requests ...
-- Uncomment and run for tables that need automatic audit:
/*
DO $$
DECLARE
  t text;
  tables text[] := ARRAY['purchase_requests','purchase_orders','stock_transfers','finance_payments','purchasing_invoices'];
BEGIN
  FOREACH t IN ARRAY tables
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%I ON %I', t, t);
    EXECUTE format('CREATE TRIGGER trg_audit_%I AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger()', t, t);
  END LOOP;
END $$;
*/

-- ============================================================================
-- PART 4: TRANSACTION LOCKING HELPERS
-- ============================================================================

-- Lock a document by ID for update (call at start of critical RPC)
-- Usage: PERFORM fn_lock_document('stock_transfers', p_transfer_id);
CREATE OR REPLACE FUNCTION fn_lock_document(p_table text, p_id uuid)
RETURNS void AS $$
DECLARE
  v_lock_id bigint;
BEGIN
  v_lock_id := hashtext(p_table || '-' || p_id::text);
  PERFORM pg_advisory_xact_lock(v_lock_id);
END;
$$ LANGUAGE plpgsql;

-- Lock by composite key (e.g. for GRN+batch)
CREATE OR REPLACE FUNCTION fn_lock_composite(p_key text)
RETURNS void AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(p_key));
END;
$$ LANGUAGE plpgsql;

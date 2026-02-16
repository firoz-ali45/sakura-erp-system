-- Transfer Order workflow alignment
-- Adds normalized status enum, TO number sequence, and workflow RPC wrappers.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transfer_status') THEN
    CREATE TYPE transfer_status AS ENUM ('draft', 'pending', 'approved', 'declined', 'sent', 'closed');
  END IF;
END $$;

CREATE SEQUENCE IF NOT EXISTS transfer_order_number_seq START 1;

CREATE TABLE IF NOT EXISTS transfer_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_number text UNIQUE,
  from_location_id uuid,
  to_location_id uuid,
  status transfer_status NOT NULL DEFAULT 'draft',
  business_date date DEFAULT CURRENT_DATE,
  requested_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS transfer_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id uuid NOT NULL REFERENCES transfer_orders(id) ON DELETE CASCADE,
  item_id uuid NOT NULL,
  requested_qty numeric(14,3) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION fn_submit_transfer_order(p_transfer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_num text;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='public' AND routine_name='fn_submit_transfer') THEN
    RETURN fn_submit_transfer(p_transfer_id);
  END IF;

  UPDATE transfer_orders
  SET transfer_number = COALESCE(transfer_number, 'TO-' || lpad(nextval('transfer_order_number_seq')::text, 6, '0')),
      status = 'pending',
      updated_at = now()
  WHERE id = p_transfer_id
    AND status::text = 'draft';

  SELECT transfer_number INTO v_num FROM transfer_orders WHERE id = p_transfer_id;
  RETURN jsonb_build_object('ok', true, 'transfer_number', v_num);
END;
$$;

CREATE OR REPLACE FUNCTION fn_approve_transfer_order(p_transfer_id uuid, p_approved_by text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='public' AND routine_name='fn_approve_transfer_level') THEN
    RETURN fn_approve_transfer_level(p_transfer_id, 2, COALESCE(p_approved_by, 'system'));
  END IF;

  UPDATE transfer_orders
  SET status = 'approved',
      updated_at = now()
  WHERE id = p_transfer_id
    AND status::text IN ('pending', 'submitted', 'level1_approved', 'level2_approved');

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION fn_decline_transfer_order(p_transfer_id uuid, p_rejected_by text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='public' AND routine_name='fn_reject_transfer') THEN
    RETURN fn_reject_transfer(p_transfer_id, COALESCE(p_rejected_by, 'system'));
  END IF;

  UPDATE transfer_orders
  SET status = 'declined',
      updated_at = now()
  WHERE id = p_transfer_id
    AND status::text NOT IN ('sent', 'closed');

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION fn_send_transfer_order(p_transfer_id uuid, p_user_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema='public' AND routine_name='fn_dispatch_transfer') THEN
    RETURN fn_dispatch_transfer(p_transfer_id, COALESCE(p_user_id, 'system'));
  END IF;

  UPDATE transfer_orders
  SET status = 'sent',
      updated_at = now()
  WHERE id = p_transfer_id
    AND status::text = 'approved';

  RETURN jsonb_build_object('ok', true);
END;
$$;

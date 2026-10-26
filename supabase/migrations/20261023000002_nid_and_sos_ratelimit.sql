-- db/migrations/20261023000002_nid_and_sos_ratelimit.sql
-- Sprint 2: harden submit_verification (optional p_nid_number) and enforce 3/24h SOS rate limit trigger
-- 
-- 1. Add optional p_nid_number parameter to submit_verification (backward compatible):
--    - When p_nid_number is provided, insert into advocates.nid_number
--    - When p_nid_number is omitted (null), preserve existing nid_number (coalesce)
--    - This enables frontend to save nid_number in a single atomic RPC call.
-- 2. Add BEFORE INSERT trigger enforce_sos_rate_limit on sos_requests:
--    - Count client's sos_requests in trailing 24 hours
--    - Raise 'sos_rate_limit_exceeded' on 4th+ attempt within 24h
--    - Log breaches to audit_logs per PRD §13 and TRD §6.8.
-- 
-- Dependencies:
--   - Should run after 20261022000001 (Verification attempt guard) and 20261023000001 (Sanad storage).
--   - Uses existing function helpers: is_admin(), is_verified_advocate().

-- =====================================================================
-- Updated submit_verification: optional p_nid_number parameter
-- =====================================================================

-- Drop previous signature to avoid overload
DROP FUNCTION IF EXISTS submit_verification(text, text[], text[], text[], text[], numeric, numeric, text);

-- Recreate submit_verification with p_nid_number (optional, default null)
CREATE OR REPLACE FUNCTION submit_verification(
  p_bar_council_no text,
  p_courts text[] DEFAULT '{}',
  p_districts text[] DEFAULT '{}',
  p_specializations text[] DEFAULT '{}',
  p_languages text[] DEFAULT '{bn}',
  p_fee_min_bdt numeric DEFAULT null,
  p_fee_max_bdt numeric DEFAULT null,
  p_pin text DEFAULT null,
  p_nid_number text DEFAULT null
)
RETURNS advocates
LANGUAGE plpgsql
SECURITY DEFINER
SET SEARCH_PATH = public, extensions
AS $$
DECLARE
  v_row advocates;
  v_actor_role user_role;
BEGIN
  -- Existing authentication/authorization gates
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;

  SELECT role INTO v_actor_role FROM profiles WHERE id = auth.uid();
  IF v_actor_role <> 'advocate' THEN
    RAISE EXCEPTION 'caller must have advocate role';
  END IF;

  IF p_bar_council_no IS NULL OR BTRIM(p_bar_council_no) = '' THEN
    RAISE EXCEPTION 'bar_council_no_required';
  END IF;

  IF p_fee_min_bdt IS NOT NULL AND p_fee_max_bdt IS NOT NULL
     AND p_fee_max_bdt < p_fee_min_bdt THEN
    RAISE EXCEPTION 'fee_range_invalid';
  END IF;

  IF p_pin IS NOT NULL AND p_pin !~ '^\d{4}$' THEN
    RAISE EXCEPTION 'pin_must_be_4_digits';
  END IF;

  -- 3-attempt re-application limit guard (from 20261022000001)
  IF EXISTS (
    SELECT 1
    FROM advocates
    WHERE profile_id = auth.uid()
      AND attempts >= 3
  ) THEN
    RAISE EXCEPTION 'max_verification_attempts_reached: maximum verification re-application limit (3) exceeded. Please contact admin support.';
  END IF;

  INSERT INTO advocates (
    profile_id, bar_council_no, courts, districts, specializations,
    languages, fee_min_bdt, fee_max_bdt,
    verification, rejection_reason, attempts, pin_hash, updated_at, nid_number
  )
  VALUES (
    auth.uid(),
    TRIM(p_bar_council_no),
    p_courts, p_districts, p_specializations,
    p_languages, p_fee_min_bdt, p_fee_max_bdt,
    'pending', NULL,
    COALESCE((SELECT attempts FROM advocates WHERE profile_id = auth.uid()), 0),
    CASE WHEN p_pin IS NOT NULL THEN crypt(p_pin, gen_salt('bf', 10)) END,
    NOW(),
    COALESCE(NULLIF(TRIM(p_nid_number), ''), (SELECT nid_number FROM advocates WHERE profile_id = auth.uid()))
  )
  ON CONFLICT (profile_id) DO UPDATE SET
    bar_council_no = EXCLUDED.bar_council_no,
    courts = EXCLUDED.courts,
    districts = EXCLUDED.districts,
    specializations = EXCLUDED.specializations,
    languages = EXCLUDED.languages,
    fee_min_bdt = EXCLUDED.fee_min_bdt,
    fee_max_bdt = EXCLUDED.fee_max_bdt,
    verification = 'pending',
    rejection_reason = NULL,
    pin_hash = COALESCE(EXCLUDED.pin_hash, advocates.pin_hash),
    updated_at = NOW(),
    nid_number = COALESCE(NULLIF(TRIM(EXCLUDED.nid_number), ''), advocates.nid_number)
  RETURNING * INTO v_row;

  INSERT INTO audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
  VALUES (
    auth.uid(),
    v_actor_role,
    'advocate.submit_verification',
    'advocates',
    v_row.profile_id,
    jsonb_build_object('bar_council_no', TRIM(p_bar_council_no), 'nid_number', COALESCE(NULLIF(TRIM(p_nid_number), ''), v_row.nid_number))
  );

  RETURN v_row;
END;
$$;

REVOKE EXECUTE ON FUNCTION submit_verification(text, text[], text[], text[], text[], numeric, numeric, text, text) FROM public;
GRANT EXECUTE ON FUNCTION submit_verification(text, text[], text[], text[], text[], numeric, numeric, text, text) TO authenticated;

-- =====================================================================
-- ENFORCE SOS RATE LIMIT (3 per 24 hours per client) TRIGGER
-- =====================================================================

-- Rate limit check: client may not have more than 3 sos_requests in last 24h
CREATE OR REPLACE FUNCTION enforce_sos_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET SEARCH_PATH = public, extensions
AS $$
DECLARE
  v_recent_count integer;
BEGIN
  SELECT COUNT(*) INTO v_recent_count
  FROM sos_requests
  WHERE client_id = NEW.client_id
    AND created_at > NOW() - INTERVAL '24 hours';

  IF v_recent_count >= 3 THEN
    -- Log the breach
    INSERT INTO audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
    VALUES (
      auth.uid(),
      (SELECT role FROM profiles WHERE id = auth.uid()),
      'sos_rate_limit_exceeded',
      'sos_requests',
      NEW.id,
      jsonb_build_object(
        'client_id', NEW.client_id,
        'rate_limit', 3,
        'recent_count', v_recent_count,
        'window_hours', 24
      )
    );

    RAISE EXCEPTION 'sos_rate_limit_exceeded: maximum 3 SOS requests allowed per 24 hours';
  END IF;

  RETURN NEW;
END;
$$;

-- Create the BEFORE INSERT trigger
DROP TRIGGER IF EXISTS trg_sos_rate_limit ON sos_requests;
CREATE TRIGGER trg_sos_rate_limit
  BEFORE INSERT ON sos_requests
  FOR EACH ROW
  EXECUTE FUNCTION enforce_sos_rate_limit();

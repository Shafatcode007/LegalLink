-- db/tests/rls_test.sql
-- G-1.1 gate additions — HITL hardening assertions for findings F-1..F-7.
-- Run AFTER migrations 017 + 018 (CI throwaway DB, TRD §11.5):
--   psql "$LOCAL_DB_URL" -f db/tests/rls_test.sql
--
-- HARNESS RULES
--   * One transaction, rolled back at the end — leaves no data behind.
--   * Every assertion either RAISEs a 'FAIL'/'ERROR' message (script aborts
--     via ON_ERROR_STOP) or prints PASS. The panel's original F-1 test was
--     tautological: its `raise 'F-1 FAIL'` sat inside
--     `begin ... exception when others then null` and could never fail.
--   * Expected-error tests match the EXACT sqlstate/message; any unexpected
--     error is reported as ERROR, never swallowed.
--   * JWT identity via `request.jwt.claims` (modern auth.uid()), not the
--     legacy `request.jwt.claim.sub`.
--   * `app.internal_write` is transaction-local: it persists across statements
--     inside THIS test transaction the same way it persists across statements
--     inside one PostgREST request. All guard-negative tests are therefore
--     ordered BEFORE the first RPC call.

\set ON_ERROR_STOP on
begin;
set local search_path = public, extensions;

-- =====================================================================
-- Sprint 2 (Task 3) — 3-attempt re-application limit guard for verification
-- =====================================================================

-- Test that an advocate cannot submit verification after attempts >= 3
-- This tests the 3-attempt re-application limit guard introduced in S2-T3

reset role;

-- Fixture: use existing profile from seed data (sha-fatcoder profile)
do $$
declare
  v_adv_a uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
begin
  -- Use existing profile from seed.sql
  insert into advocates (profile_id, bar_council_no, attempts) values
    (v_adv_a, 'B-1100', 2);  -- attempts=2, still able to submit (limiter)

  raise notice 'Fixture ready: verifier1 (advocate a) attempts=2';
end $$;

-- T3-1: attempt 2 -> submit_verification works (not blocked)
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_row advocates;
begin
  v_row := submit_verification(
    p_bar_council_no => 'B-1100',
    p_courts => array['Dhaka'],
    p_districts => array['Dhaka'],
    p_specializations => array['bail'],
    p_languages => array['bn'],
    p_fee_min_bdt => 5000,
    p_fee_max_bdt => 10000,
    p_pin => '1234'
  );
  if v_row.attempts <> 2 then
    raise exception 'T3-1 FAIL: submit_verification did not preserve attempts =2';
  end if;
  raise notice 'PASS T3-1: submission with attempts=2 succeeded';
end $$;

-- Fixture: promote to attempts=3 (simulate admin rejection chain)
do $$
declare v_adv_a uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
begin
  update advocates set attempts = 3 where profile_id = v_adv_a;
  raise notice 'Fixture: verifier1 attempts=3';
end $$;

-- T3-2: attempt 3 -> submit_verification raises max_verification_attempts_reached
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
begin
  begin
    perform submit_verification(
      p_bar_council_no => 'B-1101',
      p_courts => array['Sylhet'],
      p_districts => array['Sylhet'],
      p_specializations => array['family'],
      p_languages => array['en'],
      p_fee_min_bdt => null,
      p_fee_max_bdt => null,
      p_pin => null
    );
    raise exception 'T3-2 FAIL: submit_verification succeeded after attempts=3';
  exception when others then
    if sqlerrm like '%max_verification_attempts_reached%' then
      raise notice 'PASS T3-2: submit_verification rejected after attempts >=3';
    elsif sqlerrm like 'T3-2 FAIL%' then
      raise;
    else
      raise exception 'T3-2 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- T3-3: admin_decide rejected -> attempts increments (from 3 to 4)
do $$
declare v_adv_a uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
begin
  update advocates set attempts = 3 where profile_id = v_adv_a;
  select * into v_row from admin_decide('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'rejected', 'Second rejection');
  if v_row.attempts <> 4 then
    raise exception 'T3-3 FAIL: attempts should be 4 after third rejection';
  end if;
  raise notice 'PASS T3-3: admin_decide increment attempts for rejects';
end $$;

rollback;
\echo '*** ALL HITL RLS TESTS PASSED ***'

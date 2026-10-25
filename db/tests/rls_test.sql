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
-- Fixtures (superuser): 2 clients, 2 advocates, 1 admin, 2 cases,
-- 4 drafts (2 publishable, 1 expired, 1 for admin-reason test).
-- =====================================================================
do $$
declare
  v_client_a uuid := '11111111-1111-1111-1111-111111111111';
  v_client_b uuid := '22222222-2222-2222-2222-222222222222';
  v_adv_a    uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_adv_b    uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_admin    uuid := 'dddddddd-dddd-dddd-dddd-dddddddddddd';
begin
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
  values (v_client_a, 'authenticated', 'authenticated', 'client_a@test.local', 'x', now(), '+8801711000001', now()),
         (v_client_b, 'authenticated', 'authenticated', 'client_b@test.local', 'x', now(), '+8801711000002', now()),
         (v_adv_a,    'authenticated', 'authenticated', 'adv_a@test.local',    'x', now(), '+8801711000003', now()),
         (v_adv_b,    'authenticated', 'authenticated', 'adv_b@test.local',    'x', now(), '+8801711000004', now()),
         (v_admin,    'authenticated', 'authenticated', 'admin@test.local',    'x', now(), '+8801711000005', now()),
       ('00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client_x@test.local', 'x', now(), '+8801711000006', now())
  on conflict (id) do nothing;

  insert into profiles (id, role, phone) values
    (v_client_a, 'client',   '+8801700000001'),
    (v_client_b, 'client',   '+8801700000002'),
    (v_adv_a,    'advocate', '+8801700000003'),
    (v_adv_b,    'advocate', '+8801700000004'),
    (v_admin,    'admin',    '+8801700000005');

  insert into advocates (profile_id, bar_council_no, pin_hash) values
    (v_adv_a, 'B-1001', crypt('1234', gen_salt('bf', 10))),
    (v_adv_b, 'B-1002', crypt('5678', gen_salt('bf', 10)));

  insert into cases (id, client_id, advocate_id, case_type, state) values
    ('99999999-9999-9999-9999-999999999991', v_client_a, v_adv_a, 'criminal', 'active'),
    ('99999999-9999-9999-9999-999999999992', v_client_b, v_adv_b, 'family', 'active');

  insert into ai_summaries (id, case_id, raw_input, draft_bn, state, expires_at) values
    ('77777777-7777-7777-7777-777777777701',
      '99999999-9999-9999-9999-999999999991', 'PII notes 1', 'ai draft 1', 'draft', now() + interval '7 days'),
    ('77777777-7777-7777-7777-777777777702',
      '99999999-9999-9999-9999-999999999991', 'PII notes 2', 'ai draft 2', 'draft', now() + interval '7 days'),
    ('77777777-7777-7777-7777-777777777703',
      '99999999-9999-9999-9999-999999999991', 'PII notes 3', 'ai draft 3', 'draft', now() - interval '1 day'),
    ('77777777-7777-7777-7777-777777777705',
      '99999999-9999-9999-9999-999999999991', 'PII notes 5', 'ai draft 5', 'draft', now() + interval '7 days');

  raise notice 'fixtures ready';
end $$;

-- =====================================================================
-- T1 / F-1a — advocate direct UPDATE must be denied (42501, revoke)
-- =====================================================================
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
begin
  begin
    update ai_summaries set state = 'published'
     where id = '77777777-7777-7777-7777-777777777701';
    raise exception 'F-1a FAIL: direct UPDATE to published succeeded';
  exception when others then
    if sqlstate = '42501' then
      raise notice 'PASS F-1a: direct UPDATE denied (42501)';
    elsif sqlerrm like 'F-1a FAIL%' then
      raise;
    else
      raise exception 'F-1a ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- =====================================================================
-- T2 / F-1b — direct INSERT with state='published' must hit insert guard
-- =====================================================================
do $$
begin
  begin
    insert into ai_summaries (id, case_id, raw_input, draft_bn, state)
    values ('77777777-7777-7777-7777-777777777799',
            '99999999-9999-9999-9999-999999999991', 'x', 'y', 'published');
    raise exception 'F-1b FAIL: direct published INSERT succeeded';
  exception when others then
    if sqlerrm like 'hitl_gate%' then
      raise notice 'PASS F-1b: insert guard rejected published state';
    elsif sqlerrm like 'F-1b FAIL%' then
      raise;
    else
      raise exception 'F-1b ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- =====================================================================
-- T3 / F-3a — advocate cannot reset own PIN counters (pin_guard)
-- =====================================================================
do $$
begin
  begin
   update advocates set pin_fail_count = 99, pin_locked_until = now()
     where profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    raise exception 'F-3a FAIL: advocate reset own PIN lockout';
  exception when others then
    if sqlerrm like 'pin_guard%' then
      raise notice 'PASS F-3a: pin_guard blocked self-reset';
    elsif sqlerrm like 'F-3a FAIL%' then
      raise;
    else
      raise exception 'F-3a ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- =====================================================================
-- T4 / F-3b — REGRESSION GUARD: legit advocate profile edit still works
--   (this is what the panel's column-GRANT approach would have broken)
-- =====================================================================
do $$
declare v_n int;
begin
  update advocates set specializations = array['criminal']
   where profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'F-3b FAIL: legit profile update affected % rows', v_n;
  end if;
  raise notice 'PASS F-3b: advocate profile edit unaffected';
exception when others then
  if sqlerrm like 'F-3b FAIL%' then
    raise;
  else
    raise exception 'F-3b ERROR: legit profile update broken: %', sqlerrm;
  end if;
end $$;

-- =====================================================================
-- T5 / F-3c — REGRESSION GUARD: admin verification PATCH still works
--   (column GRANTs on the shared `authenticated` role would have broken this)
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_n int;
begin
  update advocates
     set verification = 'verified', verified_at = now()
   where profile_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'F-3c FAIL: admin verification PATCH affected % rows', v_n;
  end if;
  raise notice 'PASS F-3c: admin verification PATCH unaffected';
exception when others then
  if sqlerrm like 'F-3c FAIL%' then
    raise;
  else
    raise exception 'F-3c ERROR: admin PATCH broken: %', sqlerrm;
  end if;
end $$;

-- =====================================================================
-- T6 / F-4 — non-owner advocate cannot publish (caller-identity assertion)
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_ret ai_summaries;
begin
  begin
    v_ret := publish_ai_summary('77777777-7777-7777-7777-777777777701',
                                '5678', 'forged final');
    raise exception 'F-4 FAIL: non-owner publish returned a row';
  exception when others then
    if sqlerrm = 'not_case_advocate' then
      raise notice 'PASS F-4: caller-identity assertion enforced';
    elsif sqlerrm like 'F-4 FAIL%' then
      raise;
    else
      raise exception 'F-4 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- -- =====================================================================
-- T7 — success path: correct PIN publishes, counter reset, audit + notice
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_row ai_summaries; v_n int;
begin
  v_row := publish_ai_summary('77777777-7777-7777-7777-777777777701',
                              '1234', 'advocate-approved final text');
  if v_row is null or v_row.state <> 'published'
     or v_row.published_by <> 'advocate'
     or v_row.final_bn <> 'advocate-approved final text' then
    raise exception 'T7 FAIL: publish did not return the published row';
  end if;

  select pin_fail_count into v_n from advocates
   where profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  if v_n <> 0 then
    raise exception 'T7 FAIL: fail counter not reset on success (%)', v_n;
  end if;

  -- DEBUG: Force superuser role to bypass ANY RLS policies on audit_logs
  set local role postgres;
  
  raise notice 'DEBUG: Checking audit_logs as superuser (postgres)';
  
  select count(*) into v_n from audit_logs
   where action = 'summary.publish'
     and entity_id = '77777777-7777-7777-7777-777777777701';
     
  raise notice 'DEBUG: audit_logs count = %', v_n;
  
  if v_n <> 1 then
    raise exception 'T7 FAIL: audit row missing (%)', v_n;
  end if;

  select count(*) into v_n from notifications
   where dedupe_key = 'summary:77777777-7777-7777-7777-777777777701';
  if v_n <> 1 then
    raise exception 'T7 FAIL: notification fan-out missing (%)', v_n;
  end if;

  raise notice 'PASS T7: publish success path + audit + notification';
exception when others then
  if sqlerrm like 'T7 FAIL%' then
    raise;
  else
    raise exception 'T7 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
  end if;
end $$;

-- =====================================================================
-- T8 — lockout durability (the D1 rollback regression):
--   5 wrong PINs -> counter MUST read 1..5 after each call (a design that
--   raises 'invalid_pin' after incrementing shows 0 here — subtransaction
--   rollback in this harness == full transaction rollback under PostgREST),
--   then the 6th call with the CORRECT pin must return 'pin_locked'.
-- =====================================================================
do $$
declare v_count int; v_ret ai_summaries;
begin
  for i in 1..5 loop
    v_ret := publish_ai_summary('77777777-7777-7777-7777-777777777702',
                                '9999', 'should never publish');
    if v_ret is not null then
      raise exception 'T8 FAIL: wrong PIN returned a row (attempt %)', i;
    end if;
    select pin_fail_count into v_count from advocates
     where profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    if v_count <> i then
      raise exception
        'T8 FAIL: pin_fail_count=% after attempt % — counter not persisted (rollback bug)', v_count, i;
    end if;
  end loop;

  begin
    v_ret := publish_ai_summary('77777777-7777-7777-7777-777777777702',
                                '1234', 'correct pin while locked');
    raise exception 'T8 FAIL: locked advocate was allowed to publish';
  exception when others then
    if sqlerrm = 'pin_locked' then
      raise notice 'PASS T8: lockout enforced after 5 attempts (counter durable)';
    elsif sqlerrm like 'T8 FAIL%' then
      raise;
    else
      raise exception 'T8 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- =====================================================================
-- T9 — advocate cannot use the admin override
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_ret ai_summaries;
begin
  begin
    v_ret := admin_force_publish('77777777-7777-7777-7777-777777777702',
                                 'bypass attempt');
    raise exception 'T9 FAIL: advocate invoked admin override';
  exception when others then
    if sqlerrm = 'not_admin' then
      raise notice 'PASS T9: admin override rejected for advocate';
    elsif sqlerrm like 'T9 FAIL%' then
      raise;
    else
      raise exception 'T9 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- =====================================================================
-- T10 — admin paths: clear lockout (is_admin escape through pin_guard),
--   empty reason refused, override publish works with GUC handshake
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_n int; v_row ai_summaries;
begin
  -- admin may clear PIN counters (is_admin escape — §9.3 reset flow)
  update advocates set pin_fail_count = 0, pin_locked_until = null
   where profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'T10 FAIL: admin cannot clear PIN lockout: affected % rows', v_n;
  end if;

  -- empty reason must be refused
  begin
    v_row := admin_force_publish('77777777-7777-7777-7777-777777777705', '   ');
    raise exception 'T10 FAIL: empty override reason accepted';
  exception when others then
    if sqlerrm = 'reason_required' then
      raise notice 'PASS T10a: empty override reason refused';
    elsif sqlerrm like 'T10 FAIL%' then
      raise;
    else
      raise exception 'T10 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;

  -- override publish must pass the publish guard (GUC set inside RPC)
  v_row := admin_force_publish('77777777-7777-7777-7777-777777777702',
                               'identity re-check completed');
  if v_row is null or v_row.state <> 'published'
     or v_row.published_by <> 'admin_override' then
    raise exception 'T10 FAIL: admin override did not publish';
  end if;

  select count(*) into v_n from audit_logs
   where action = 'admin.override'
     and entity_id = '77777777-7777-7777-7777-777777777702';
  if v_n <> 1 then
    raise exception 'T10 FAIL: admin.override audit row missing (%)', v_n;
  end if;

  raise notice 'PASS T10: admin lockout clear + override publish + audit';
exception when others then
  if sqlerrm like 'T10 FAIL%' then
    raise;
  else
    raise exception 'T10 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
  end if;
end $$;

-- =====================================================================
-- T11 — expired draft refused BEFORE any counter mutation
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_ret ai_summaries; v_count int;
begin
  begin
    v_ret := publish_ai_summary('77777777-7777-7777-7777-777777777703',
                                '1234', 'expired draft final');
    raise exception 'T11 FAIL: expired draft published';
  exception when others then
    if sqlerrm = 'draft_expired' then
      raise notice 'PASS T11: expired draft refused';
    elsif sqlerrm like 'T11 FAIL%' then
      raise;
    else
      raise exception 'T11 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;

  select pin_fail_count into v_count from advocates
   where profile_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  if v_count <> 0 then
    raise exception 'T11 FAIL: counter mutated by refused publish (%)', v_count;
  end if;
end $$;

-- =====================================================================
-- T12 / F-6 — client isolation: base table invisible, view safe
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_n int; v_col int;
begin
  select count(*) into v_n from ai_summaries;
  if v_n <> 0 then
    raise exception 'F-6 FAIL: client read base table (%)', v_n;
  end if;

  select count(*) into v_n from client_ai_summaries
   where id = '77777777-7777-7777-7777-777777777701';
  if v_n <> 1 then
    raise exception 'F-6 FAIL: view missing own published row (%)', v_n;
  end if;

  select count(*) into v_col from information_schema.columns
   where table_schema = 'public'
     and table_name = 'client_ai_summaries'
     and column_name in ('raw_input', 'draft_bn', 'flagged', 'override_reason');
  if v_col <> 0 then
    raise exception 'F-6 FAIL: view exposes % sensitive columns', v_col;
  end if;

  raise notice 'PASS F-6: client sees view only, PII columns hidden';
exception when others then
  if sqlerrm like 'F-6 FAIL%' then
    raise;
  else
    raise exception 'F-6 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
  end if;
end $$;

-- cross-client isolation through the view (owner-rights view + baked predicate)
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_n int;
begin
  select count(*) into v_n from client_ai_summaries;
  if v_n <> 0 then
    raise exception 'F-6 FAIL: cross-client view leak (%)', v_n;
  end if;
  raise notice 'PASS F-6b: cross-client isolation through view';
exception when others then
  if sqlerrm like 'F-6 FAIL%' then
    raise;
  else
    raise exception 'F-6b ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
  end if;
end $$;

-- =====================================================================
-- T13 / F-7 — admin_override without reason rejected by CHECK
-- =====================================================================
reset role;
select set_config('request.jwt.claims', '', true);

do $$
begin
  begin
    insert into ai_summaries (id, case_id, raw_input, draft_bn, state, published_by)
    values ('77777777-7777-7777-7777-777777777704',
            '99999999-9999-9999-9999-999999999991',
            'r', 'd', 'draft', 'admin_override');
    raise exception 'F-7 FAIL: admin_override without reason accepted';
  exception when check_violation then
    raise notice 'PASS F-7: published_requires_reason constraint enforced';
  when others then
    if sqlerrm like 'F-7 FAIL%' then
      raise;
    else
      raise exception 'F-7 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- =====================================================================
-- complete_signup role guard: client must not self-assign 'admin'
-- =====================================================================
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

do $$
declare
  v_role user_role;
begin
  -- 1) Client must NOT be able to self-assign 'admin'
  begin
    perform complete_signup('admin'::user_role, 'Malicious Admin', 'bn');
    raise exception 'SECURITY BREACH: admin self-assignment was not rejected';
  exception when others then
    if sqlerrm not like '%forbidden_role_assignment%' then
      raise exception 'SECURITY BREACH: unexpected rejection message: %', sqlerrm;
    end if;
    raise notice 'PASS complete_signup: admin self-assignment rejected';
  end;

  -- 2) Client CAN self-assign 'advocate'
  begin
    perform complete_signup('advocate'::user_role, 'Valid Advocate', 'bn');
  exception when others then
    raise exception 'SECURITY BREACH: advocate self-assignment rejected: %', sqlerrm;
  end;

  select role into v_role from profiles where id = '00000000-0000-0000-0000-000000000001';
  if v_role <> 'advocate' then
    raise exception 'SECURITY BREACH: advocate role not persisted (got %)', v_role;
  end if;
  raise notice 'PASS complete_signup: advocate role assigned and persisted';
end $$;

-- =====================================================================
-- Verification RPCs: submit_verification / admin_decide
-- =====================================================================
-- Test as client_a (role = 'client')
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);

do $$
declare
  v_row advocates;
  v_role user_role;
begin
  -- 1) Client cannot submit verification (not an advocate role)
  begin
    perform submit_verification('B-1003');
    raise exception 'SECURITY BREACH: client submit_verification not rejected';
  exception when others then
    if sqlerrm not like '%caller must have advocate role%' then
      raise exception 'SECURITY BREACH: unexpected message: %', sqlerrm;
    end if;
    raise notice 'PASS submit_verification: client rejected';
  end;

  -- 2) Advocate with invalid 3-digit PIN rejected
  execute 'set local role authenticated;';
  perform set_config('request.jwt.claims', json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
  begin
    perform submit_verification('B-1001', p_pin => '123');
    raise exception 'SECURITY BREACH: short PIN not rejected';
  exception when others then
    if sqlerrm not like '%pin_must_be_4_digits%' then
      raise exception 'SECURITY BREACH: unexpected message: %', sqlerrm;
    end if;
    raise notice 'PASS submit_verification: short PIN rejected';
  end;

  -- 3) Advocate submits verification -> row with verification = 'pending'
  begin
    select * into v_row from submit_verification('B-1009');
  exception when others then
    raise exception 'SECURITY BREACH: advocate submit_verification failed: %', sqlerrm;
  end;
  if v_row.verification <> 'pending' then
    raise exception 'SECURITY BREACH: verification not pending (got %)', v_row.verification;
  end if;
  raise notice 'PASS submit_verification: advocate row verification = pending';

  -- 4) Client cannot call admin_decide
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
  begin
    perform admin_decide('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'verified');
    raise exception 'SECURITY BREACH: client admin_decide not rejected';
  exception when others then
    if sqlerrm not like '%forbidden: admin privileges required%' then
      raise exception 'SECURITY BREACH: unexpected message: %', sqlerrm;
    end if;
    raise notice 'PASS admin_decide: client rejected';
  end;

  -- 5) Admin reject with null reason rejected
  execute 'set local role authenticated;';
  perform set_config('request.jwt.claims', json_build_object('sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'role', 'authenticated')::text, true);
  begin
    perform admin_decide('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'rejected', null);
    raise exception 'SECURITY BREACH: reject without reason not rejected';
  exception when others then
    if sqlerrm not like '%rejection_reason_required%' then
      raise exception 'SECURITY BREACH: unexpected message: %', sqlerrm;
    end if;
    raise notice 'PASS admin_decide: reject without reason rejected';
  end;

  -- 6) Admin verify -> verification = 'verified', verified_at not null
  begin
    select * into v_row from admin_decide('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'verified');
  exception when others then
    raise exception 'SECURITY BREACH: admin verify failed: %', sqlerrm;
  end;
  if v_row.verification <> 'verified' or v_row.verified_at is null then
    raise exception 'SECURITY BREACH: verify did not persist (verification=%, verified_at=%)',
      v_row.verification, v_row.verified_at;
  end if;
  raise notice 'PASS admin_decide: verified + verified_at set';
end $$;

-- =====================================================================
-- Sprint 2 (Task 1) — sanad bucket storage RLS + update_advocate_documents
-- =====================================================================
reset role;

-- S2-1: a client (role='client') cannot write into the sanad bucket, even
--       inside its own {uid}/ folder (restrictive advocate-only policy).
select set_config('request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('sanad', '11111111-1111-1111-1111-111111111111/sanad.jpg',
            '11111111-1111-1111-1111-111111111111');
    raise exception 'S2-1 FAIL: client inserted into sanad bucket';
  exception when others then
    if sqlstate = '42501' then
      raise notice 'PASS S2-1: client sanad insert denied (42501)';
    elsif sqlerrm like 'S2-1 FAIL%' then
      raise;
    else
      raise exception 'S2-1 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- S2-2: an advocate cannot write into another advocate's folder.
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('sanad', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/sanad.jpg',
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
    raise exception 'S2-2 FAIL: cross-folder sanad insert succeeded';
  exception when others then
    if sqlstate = '42501' then
      raise notice 'PASS S2-2: cross-folder sanad insert denied (42501)';
    elsif sqlerrm like 'S2-2 FAIL%' then
      raise;
    else
      raise exception 'S2-2 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- S2-3: an advocate CAN write into its own {uid}/ folder.
do $$
begin
  insert into storage.objects (bucket_id, name, owner)
  values ('sanad', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/sanad.jpg',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  raise notice 'PASS S2-3: advocate own-folder sanad insert allowed';
exception when others then
  raise exception 'S2-3 ERROR: advocate own-folder insert failed: % (%)', sqlerrm, sqlstate;
end $$;

-- S2-4: a non-admin cannot read the sanad bucket back.
do $$
declare v_n int;
begin
  select count(*) into v_n from storage.objects where bucket_id = 'sanad';
  if v_n <> 0 then
    raise exception 'S2-4 FAIL: non-admin read % sanad object(s)', v_n;
  end if;
  raise notice 'PASS S2-4: non-admin cannot read sanad objects';
exception when others then
  if sqlerrm like 'S2-4 FAIL%' then
    raise;
  else
    raise exception 'S2-4 ERROR: %', sqlerrm;
  end if;
end $$;

-- S2-5: an admin CAN read the sanad bucket.
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_n int;
begin
  select count(*) into v_n from storage.objects where bucket_id = 'sanad';
  if v_n < 1 then
    raise exception 'S2-5 FAIL: admin could not read sanad objects (%)', v_n;
  end if;
  raise notice 'PASS S2-5: admin can read sanad objects';
exception when others then
  if sqlerrm like 'S2-5 FAIL%' then
    raise;
  else
    raise exception 'S2-5 ERROR: %', sqlerrm;
  end if;
end $$;

-- S2-6: a client cannot call update_advocate_documents.
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
begin
  begin
    perform update_advocate_documents('11111111-1111-1111-1111-111111111111/sanad.jpg', null);
    raise exception 'S2-6 FAIL: client update_advocate_documents not rejected';
  exception when others then
    if sqlerrm not like '%caller must have advocate role%' then
      raise exception 'S2-6 ERROR: unexpected error: %', sqlerrm;
    end if;
    raise notice 'PASS S2-6: client update_advocate_documents rejected';
  end;
end $$;

-- S2-7 / S2-8 / S2-9: advocate RPC contract (run as advocate).
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_row advocates;
begin
  -- S2-7: no documents provided is refused.
  begin
    perform update_advocate_documents(null, null);
    raise exception 'S2-7 FAIL: empty update accepted';
  exception when others then
    if sqlerrm like 'no_documents_provided%' then
      raise notice 'PASS S2-7: empty update refused';
    elsif sqlerrm like 'S2-7 FAIL%' then
      raise;
    else
      raise exception 'S2-7 ERROR: unexpected error: %', sqlerrm;
    end if;
  end;

  -- S2-8: valid update persists both paths on the caller's own row.
  select * into v_row from update_advocate_documents(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/sanad.jpg',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/nid.jpg');
  if v_row.sanad_url is null or v_row.nid_url is null then
    raise exception 'S2-8 FAIL: urls not persisted (sanad=%, nid=%)',
      v_row.sanad_url, v_row.nid_url;
  end if;
  raise notice 'PASS S2-8: advocate document urls persisted';
exception when others then
  if sqlerrm like 'S2-8 FAIL%' then
    raise;
  else
    raise exception 'S2-8 ERROR: %', sqlerrm;
  end if;
end $$;

-- S2-9: the upload is audited (superuser read bypasses audit_logs RLS).
reset role;
do $$
declare v_n int;
begin
  select count(*) into v_n from audit_logs
   where action = 'advocate.upload_credentials'
     and entity_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  if v_n <> 1 then
    raise exception 'S2-9 FAIL: upload_credentials audit row missing (%)', v_n;
  end if;
  raise notice 'PASS S2-9: advocate.upload_credentials audited';
exception when others then
  if sqlerrm like 'S2-9 FAIL%' then
    raise;
  else
    raise exception 'S2-9 ERROR: %', sqlerrm;
  end if;
end $$;

-- =====================================================================
-- complete_signup phone resolution (auth.users is authoritative)
-- =====================================================================
reset role;

-- Probes: one auth account WITH a registered phone, one WITHOUT any phone.
insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
values ('00000000-0000-0000-0000-0000000000aa', 'authenticated', 'authenticated',
        'probe_phone@test.local', 'x', now(), '+8801700000009', now()),
       ('00000000-0000-0000-0000-0000000000bb', 'authenticated', 'authenticated',
        'probe_nophone@test.local', 'x', now(), null, null)
on conflict (id) do nothing;

-- T-PHONE-1 — phone in auth.users, none in JWT -> must resolve from auth.users.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-0000000000aa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_phone text;
begin
  perform complete_signup('client'::user_role, 'Phone Probe', 'bn');
  select phone into v_phone from profiles where id = '00000000-0000-0000-0000-0000000000aa';
  if v_phone is null or v_phone = '' then
    raise exception 'T-PHONE-1 FAIL: phone not resolved (got %)', coalesce(v_phone, '<null>');
  end if;
  if v_phone <> '+8801700000009' then
    raise exception 'T-PHONE-1 FAIL: expected +8801700000009, got %', v_phone;
  end if;
  raise notice 'PASS T-PHONE-1: phone resolved from auth.users';
exception when others then
  if sqlerrm like 'T-PHONE-1 FAIL%' then
    raise;
  else
    raise exception 'T-PHONE-1 ERROR: % (%)', sqlerrm, sqlstate;
  end if;
end $$;

-- T-PHONE-2 — no phone anywhere -> phone_not_found (no empty-string phone).
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-0000000000bb', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
begin
  begin
    perform complete_signup('client'::user_role, 'No Phone Probe', 'bn');
    raise exception 'T-PHONE-2 FAIL: complete_signup succeeded without a phone';
  exception when others then
    if sqlerrm like 'phone_not_found%' then
      raise notice 'PASS T-PHONE-2: missing phone rejected';
    elsif sqlerrm like 'T-PHONE-2 FAIL%' then
      raise;
    else
      raise exception 'T-PHONE-2 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- =====================================================================
-- Sprint 2 (Task 2) — accept_sos: single-accept row lock, case creation,
-- checklist cloning, audit + notification fan-out.
--
-- True two-session concurrency (dblink / two psql connections) cannot run
-- inside this harness: every rule is one transaction, rolled back at the end
-- (TRD §11.5 harness rules). That race demo lands in S3·W3 (sprint.md).
-- Here we simulate the race sequentially: the second caller matches zero
-- rows because status <> 'open', so it gets NULL (sos_already_taken) — which
-- exercises the exact `status = 'open'` predicate that delivers the lock.
-- =====================================================================

reset role;

-- Fixtures: a pending (unverified) advocate + one open SOS owned by client_a.
do $$
declare
  v_adv_c uuid := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  v_sos   uuid := '55555555-5555-5555-5555-555555555501';
begin
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
  values (v_adv_c, 'authenticated', 'authenticated', 'adv_c@test.local', 'x', now(), '+8801700000007', now())
  on conflict (id) do nothing;

  insert into profiles (id, role, phone) values (v_adv_c, 'advocate', '+8801700000007')
  on conflict (id) do nothing;

  insert into advocates (profile_id, bar_council_no) values (v_adv_c, 'B-1003')
  on conflict (profile_id) do nothing;

  insert into sos_requests (id, client_id, thana, district, court, contact_phone, status)
  values (v_sos, '11111111-1111-1111-1111-111111111111', 'Ramna', 'Dhaka',
          'Dhaka CMM Court 1', '+8801711111111', 'open')
  on conflict (id) do nothing;

  raise notice 'S2-T2 fixtures ready (pending advocate cccc, open SOS 5555)';
end $$;

-- S2-T2-1 — unverified advocate gets not_verified_advocate
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_row sos_requests;
begin
  begin
    v_row := accept_sos('55555555-5555-5555-5555-555555555501');
    raise exception 'S2-T2-1 FAIL: unverified advocate accepted an open SOS';
  exception when others then
    if sqlerrm = 'not_verified_advocate' then
      raise notice 'PASS S2-T2-1: unverified advocate rejected';
    elsif sqlerrm like 'S2-T2-1 FAIL%' then
      raise;
    else
      raise exception 'S2-T2-1 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- S2-T2-2 — verified advocate A accepts; row lock returns the accepted SOS
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_row sos_requests;
begin
  v_row := accept_sos('55555555-5555-5555-5555-555555555501');
  if v_row is null then
    raise exception 'S2-T2-2 FAIL: first accept returned NULL (race lost)';
  end if;
  if v_row.status <> 'accepted'
     or v_row.advocate_id <> 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     or v_row.accepted_at is null then
    raise exception 'S2-T2-2 FAIL: accept did not flip status/advocate/accepted_at (%)', v_row;
  end if;
  raise notice 'PASS S2-T2-2: advocate A won the accept lock';
end $$;

-- S2-T2-3 — case created from the accepted SOS
reset role;
do $$
declare v_case uuid; v_n int;
begin
  select id into v_case from cases where sos_id = '55555555-5555-5555-5555-555555555501';
  if not found or v_case is null then
    raise exception 'S2-T2-3 FAIL: no case created for accepted SOS';
  end if;
  select count(*) into v_n from cases where sos_id = '55555555-5555-5555-5555-555555555501';
  if v_n <> 1 then
    raise exception 'S2-T2-3 FAIL: % cases created for one SOS (1:1 broken)', v_n;
  end if;
  if (select case_type from cases where sos_id = '55555555-5555-5555-5555-555555555501') <> 'bail' then
    raise exception 'S2-T2-3 FAIL: SOS-born case must be case_type=bail';
  end if;
  if (select state from cases where sos_id = '55555555-5555-5555-5555-555555555501') <> 'active' then
    raise exception 'S2-T2-3 FAIL: case state must be active';
  end if;
  raise notice 'PASS S2-T2-3: bail case created 1:1 with the SOS';
end $$;

-- S2-T2-4 — active bail checklist templates cloned as suggested_pending_advocate
do $$
declare v_n int; v_tmpl int;
begin
  select count(*) into v_n from checklist_items
   where case_id = (select id from cases where sos_id = '55555555-5555-5555-5555-555555555501');
  select count(*) into v_tmpl from checklist_templates
   where active and case_type = 'bail';
  if v_tmpl = 0 then
    raise exception 'S2-T2-4 FAIL: no active bail templates to clone (fixture problem)';
  end if;
  if v_n <> v_tmpl then
    raise exception 'S2-T2-4 FAIL: cloned % items, expected % bail templates', v_n, v_tmpl;
  end if;
  select count(*) into v_n from checklist_items ci
   where ci.case_id = (select id from cases where sos_id = '55555555-5555-5555-5555-555555555501')
     and ci.status <> 'suggested_pending_advocate';
  if v_n <> 0 then
    raise exception 'S2-T2-4 FAIL: % cloned items not suggested_pending_advocate', v_n;
  end if;
  select count(*) into v_n from checklist_items ci
   where ci.case_id = (select id from cases where sos_id = '55555555-5555-5555-5555-555555555501')
     and ci.template_id not in (select id from checklist_templates where active and case_type = 'bail');
  if v_n <> 0 then
    raise exception 'S2-T2-4 FAIL: % cloned items reference non-bail templates', v_n;
  end if;
  raise notice 'PASS S2-T2-4: % bail templates cloned as suggested_pending_advocate', v_tmpl;
end $$;

-- S2-T2-5 — audit row sos.accept
reset role;
do $$
declare v_n int;
begin
  select count(*) into v_n from audit_logs
   where action = 'sos.accept'
     and entity = 'sos_requests'
     and entity_id = '55555555-5555-5555-5555-555555555501'
     and actor_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     and actor_role = 'advocate';
  if v_n <> 1 then
    raise exception 'S2-T2-5 FAIL: sos.accept audit row missing (%)', v_n;
  end if;
  raise notice 'PASS S2-T2-5: sos.accept audit row written';
end $$;

-- S2-T2-6 — notification to client with dedupe key
do $$
declare v_n int;
begin
  select count(*) into v_n from notifications
   where user_id = '11111111-1111-1111-1111-111111111111'
     and kind = 'sos.accepted'
     and dedupe_key = 'sos.accepted:55555555-5555-5555-5555-555555555501';
  if v_n <> 1 then
    raise exception 'S2-T2-6 FAIL: client notification missing (%)', v_n;
  end if;
  raise notice 'PASS S2-T2-6: client notification fan-out';
end $$;

-- S2-T2-7 — second advocate B loses the race (NULL / sos_already_taken)
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare v_row sos_requests;
begin
  v_row := accept_sos('55555555-5555-5555-5555-555555555501');
  if v_row is not null then
    raise exception 'S2-T2-7 FAIL: second accept did not return NULL';
  end if;
  raise notice 'PASS S2-T2-7a: second advocate got NULL (sos_already_taken)';
end $$;

-- RLS isolation: advocate B cannot even see advocate A's case row
do $$
declare v_n int;
begin
  select count(*) into v_n from cases
   where sos_id = '55555555-5555-5555-5555-555555555501';
  if v_n <> 0 then
    raise exception 'S2-T2-7 FAIL: advocate B can see advocate A''s case (n=%)', v_n;
  end if;
  raise notice 'PASS S2-T2-7b: B cannot see A''s case (RLS isolation)';
end $$;

-- Superuser check: exactly one case, still owned by advocate A
reset role;
do $$
declare v_n int; v_all_adv_a boolean;
begin
  select count(*), bool_and(advocate_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') into v_n, v_all_adv_a from cases
   where sos_id = '55555555-5555-5555-5555-555555555501';
  if v_n <> 1 or not v_all_adv_a then
    raise exception 'S2-T2-7 FAIL: race lost but case/advocate changed (n=%, all_adv_a=%)', v_n, v_all_adv_a;
  end if;
  raise notice 'PASS S2-T2-7c: exactly one case, advocate_id still A';
end $$;

-- S2-T2-8 — create_case_from_sos is internal-only (no execute grant to authenticated)
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  begin
    perform create_case_from_sos('55555555-5555-5555-5555-555555555501');
    raise exception 'S2-T2-8 FAIL: authenticated caller executed internal RPC';
  exception when others then
    if sqlstate = '42501' then
      raise notice 'PASS S2-T2-8: create_case_from_sos denied to authenticated (42501)';
    elsif sqlerrm like 'S2-T2-8 FAIL%' then
      raise;
    else
      raise exception 'S2-T2-8 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- S2-T2-9 — accept on a non-existent / closed SOS returns NULL (no row to lock)
do $$
declare v_row sos_requests;
begin
  v_row := accept_sos('00000000-0000-0000-0000-000000000000');
  if v_row is not null then
    raise exception 'S2-T2-9 FAIL: accept of unknown SOS returned a row';
  end if;
  raise notice 'PASS S2-T2-9: accept of unknown SOS returns NULL';
end $$;


-- =====================================================================
-- Sprint 2 (Task 3) — 3-attempt re-application limit (migration 20261023000001)
-- Dedicated advocate eeee so the HITL fixtures above stay untouched.
-- =====================================================================
reset role;
do $$
declare v_adv_e uuid := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
begin
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
  values (v_adv_e, 'authenticated', 'authenticated', 'adv_e@test.local', 'x', now(), '+8801711000008', now());
  insert into profiles (id, role, phone) values (v_adv_e, 'advocate', '+8801711000008');
  insert into advocates (profile_id, bar_council_no, attempts) values (v_adv_e, 'B-1100', 2);
  raise notice 'S2-T3 fixture ready (advocate eeee, attempts=2)';
end $$;

-- S2-T3-1 — attempts=2: submit_verification still allowed, attempts preserved
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
declare v_row advocates;
begin
  v_row := submit_verification(
    p_bar_council_no => 'B-1100', p_courts => array['Dhaka'], p_districts => array['Dhaka'],
    p_specializations => array['bail'], p_languages => array['bn'],
    p_fee_min_bdt => 5000, p_fee_max_bdt => 10000, p_pin => '1234');
  if v_row.attempts <> 2 then
    raise exception 'S2-T3-1 FAIL: attempts changed to % (expected 2)', v_row.attempts;
  end if;
  raise notice 'PASS S2-T3-1: submission with attempts=2 succeeded';
end $$;

-- S2-T3-2 — attempts=3: submit_verification raises max_verification_attempts_reached
reset role;
update advocates set attempts = 3 where profile_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
select set_config('request.jwt.claims',
  json_build_object('sub', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  begin
    perform submit_verification(p_bar_council_no => 'B-1101');
    raise exception 'S2-T3-2 FAIL: submit_verification succeeded with attempts=3';
  exception when others then
    if sqlerrm like 'max_verification_attempts_reached%' then
      raise notice 'PASS S2-T3-2: submit_verification blocked at attempts=3';
    elsif sqlerrm like 'S2-T3-2 FAIL%' then
      raise;
    else
      raise exception 'S2-T3-2 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- S2-T3-3 — admin rejection increments attempts (3 -> 4)
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
declare v_row advocates;
begin
  v_row := admin_decide('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'rejected', 'Sanad unreadable');
  if v_row.attempts <> 4 then
    raise exception 'S2-T3-3 FAIL: attempts = % after rejection (expected 4)', v_row.attempts;
  end if;
  raise notice 'PASS S2-T3-3: admin rejection incremented attempts to 4';
end $$;

-- =====================================================================
-- Sprint 2 (Task 4) — optional p_nid_number on submit_verification
-- (migration 20261023000002). Dedicated advocate ffff with no NID.
-- =====================================================================
reset role;
do $$
declare v_adv_f uuid := 'ffffffff-ffff-ffff-ffff-ffffffffffff';
begin
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
  values (v_adv_f, 'authenticated', 'authenticated', 'adv_f@test.local', 'x', now(), '+8801711000010', now());
  insert into profiles (id, role, phone) values (v_adv_f, 'advocate', '+8801711000010');
  insert into advocates (profile_id, bar_council_no) values (v_adv_f, 'B-1200');
  raise notice 'S2-T4 fixture ready (advocate ffff, no NID)';
end $$;

reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'role', 'authenticated')::text, true);
set local role authenticated;

-- S2-T4-1 — empty-string NID with no existing value stays NULL
do $$
declare v_row advocates;
begin
  v_row := submit_verification(p_bar_council_no => 'B-1200', p_nid_number => '');
  if v_row.nid_number is not null then
    raise exception 'S2-T4-1 FAIL: empty p_nid_number stored as %', v_row.nid_number;
  end if;
  raise notice 'PASS S2-T4-1: empty p_nid_number treated as null';
end $$;

-- S2-T4-2 — provided NID is stored
do $$
declare v_row advocates;
begin
  v_row := submit_verification(p_bar_council_no => 'B-1200', p_nid_number => '9876543210');
  if v_row.nid_number is distinct from '9876543210' then
    raise exception 'S2-T4-2 FAIL: nid_number = % (expected 9876543210)', v_row.nid_number;
  end if;
  raise notice 'PASS S2-T4-2: p_nid_number stored';
end $$;

-- S2-T4-3 — null NID preserves the existing value
do $$
declare v_row advocates;
begin
  v_row := submit_verification(p_bar_council_no => 'B-1200', p_nid_number => null);
  if v_row.nid_number is distinct from '9876543210' then
    raise exception 'S2-T4-3 FAIL: null p_nid_number changed nid_number to %', v_row.nid_number;
  end if;
  raise notice 'PASS S2-T4-3: null p_nid_number preserves existing value';
end $$;

-- S2-T4-4 — empty-string NID does not overwrite the existing value
do $$
declare v_row advocates;
begin
  v_row := submit_verification(p_bar_council_no => 'B-1200', p_nid_number => '');
  if v_row.nid_number is distinct from '9876543210' then
    raise exception 'S2-T4-4 FAIL: empty p_nid_number overwrote nid_number with %', v_row.nid_number;
  end if;
  raise notice 'PASS S2-T4-4: empty p_nid_number does not overwrite';
end $$;

-- =====================================================================
-- Sprint 2 (Task 4) — SOS rate limit, 3 per client per 24 h (TRD §6.8)
-- Client B has no SOS rows, so the window starts empty.
-- =====================================================================
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);
set local role authenticated;

-- S2-T5-1 — first three SOS within 24 h are accepted
do $$
begin
  for i in 1..3 loop
    insert into sos_requests (client_id, thana, district, court, contact_phone)
    values ('22222222-2222-2222-2222-222222222222', 'Ramna', 'Dhaka', 'Dhaka CMM Court 1', '+8801711000002');
  end loop;
  raise notice 'PASS S2-T5-1: three SOS within 24 h accepted';
end $$;

-- S2-T5-2 — fourth SOS within 24 h is rejected
do $$
begin
  begin
    insert into sos_requests (client_id, thana, district, court, contact_phone)
    values ('22222222-2222-2222-2222-222222222222', 'Ramna', 'Dhaka', 'Dhaka CMM Court 1', '+8801711000002');
    raise exception 'S2-T5-2 FAIL: fourth SOS within 24 h was accepted';
  exception when others then
    if sqlerrm like 'sos_rate_limit_exceeded%' then
      raise notice 'PASS S2-T5-2: fourth SOS within 24 h blocked';
    elsif sqlerrm like 'S2-T5-2 FAIL%' then
      raise;
    else
      raise exception 'S2-T5-2 ERROR: unexpected error: % (%)', sqlerrm, sqlstate;
    end if;
  end;
end $$;

-- S2-T5-3 — once the earlier SOS age past 24 h, a new SOS is accepted
reset role;
update sos_requests set created_at = now() - interval '25 hours'
 where client_id = '22222222-2222-2222-2222-222222222222';
select set_config('request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  insert into sos_requests (client_id, thana, district, court, contact_phone)
  values ('22222222-2222-2222-2222-222222222222', 'Ramna', 'Dhaka', 'Dhaka CMM Court 1', '+8801711000002');
  raise notice 'PASS S2-T5-3: SOS accepted after the 24 h window';
end $$;


-- =====================================================================
-- Sprint 2 (Role C) — sos:{district} realtime (TRD §6.5). Realtime only
-- broadcasts tables in the supabase_realtime publication, and applies the
-- table's RLS per subscriber (sos_advocate_select_open).
-- =====================================================================
reset role;

-- S2-RT-1 — sos_requests is published to Supabase Realtime
do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime'
                    and schemaname = 'public' and tablename = 'sos_requests') then
    raise exception 'S2-RT-1 FAIL: sos_requests is not in the supabase_realtime publication';
  end if;
  raise notice 'PASS S2-RT-1: sos_requests published to supabase_realtime';
end $$;


-- =====================================================================
-- Sprint 2 (Role C) — documents bucket reads (ADR-011). Supabase only
-- issues a 15-minute signed URL to a caller who can SELECT the object, so
-- docs_read is the gate: case parties yes, everyone else no.
-- Case 9999...991 belongs to client_a (1111...) and advocate_a (aaaa...).
-- =====================================================================
reset role;
insert into storage.objects (bucket_id, name, owner)
values ('documents', '99999999-9999-9999-9999-999999999991/fir/fir.jpg',
        '11111111-1111-1111-1111-111111111111');

-- S2-SU-1 — the case's client can read the document
select set_config('request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  if not exists (select 1 from storage.objects
                  where bucket_id = 'documents' and name like '99999999-9999-9999-9999-999999999991/%') then
    raise exception 'S2-SU-1 FAIL: case client cannot read its own case document';
  end if;
  raise notice 'PASS S2-SU-1: case client can read the case document';
end $$;

-- S2-SU-2 — the case's advocate can read the document
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  if not exists (select 1 from storage.objects
                  where bucket_id = 'documents' and name like '99999999-9999-9999-9999-999999999991/%') then
    raise exception 'S2-SU-2 FAIL: assigned advocate cannot read the case document';
  end if;
  raise notice 'PASS S2-SU-2: assigned advocate can read the case document';
end $$;

-- S2-SU-3 — another client cannot read it
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
declare v_n int;
begin
  select count(*) into v_n from storage.objects
   where bucket_id = 'documents' and name like '99999999-9999-9999-9999-999999999991/%';
  if v_n <> 0 then
    raise exception 'S2-SU-3 FAIL: another client read % case document(s)', v_n;
  end if;
  raise notice 'PASS S2-SU-3: another client cannot read the case document';
end $$;

-- S2-SU-4 — an advocate not on the case cannot read it
reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'role', 'authenticated')::text, true);
set local role authenticated;
do $$
declare v_n int;
begin
  select count(*) into v_n from storage.objects
   where bucket_id = 'documents' and name like '99999999-9999-9999-9999-999999999991/%';
  if v_n <> 0 then
    raise exception 'S2-SU-4 FAIL: unassigned advocate read % case document(s)', v_n;
  end if;
  raise notice 'PASS S2-SU-4: unassigned advocate cannot read the case document';
end $$;

-- =====================================================================
rollback;
\echo '*** ALL HITL RLS TESTS PASSED ***'

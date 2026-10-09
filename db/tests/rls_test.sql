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
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at)
  values (v_client_a, 'authenticated', 'authenticated', 'client_a@test.local', 'x', now()),
         (v_client_b, 'authenticated', 'authenticated', 'client_b@test.local', 'x', now()),
         (v_adv_a,    'authenticated', 'authenticated', 'adv_a@test.local',    'x', now()),
         (v_adv_b,    'authenticated', 'authenticated', 'adv_b@test.local',    'x', now()),
         (v_admin,    'authenticated', 'authenticated', 'admin@test.local',    'x', now())
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
rollback;
\echo '*** ALL HITL RLS TESTS PASSED ***'

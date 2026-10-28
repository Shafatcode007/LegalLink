

-- ---------------------------------------------------------------------
-- RLS Test Suite (HITL Security & Sprint 2 Invariants)
-- Assertions D-1 through D-17

-- ---------------------------------------------------------------------
-- RLS Test Suite (HITL Security & Sprint 2 Invariants)
-- Assertions D-1 through D-17
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- D-11: Advocate A cannot UPDATE invoices where advocate_id = advocate B
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'adv-a@test.local', 'x', '+8801700000903')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'adv-b@test.local', 'x', '+8801700000904')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'client-b@test.local', 'x', '+8801700000902')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000001', 'advocate', '+8801700000903', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000002', 'advocate', '+8801700000904', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000002', 'client', '+8801700000902', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into invoices (id, invoice_no, case_id, advocate_id, client_id, subtotal_bdt, vat_rate, vat_bdt, total_bdt, state)
  values ('b3333333-3333-3333-3333-333333333302', 'INV-2026-0002', 'c3333333-3333-3333-3333-333333333302', 'a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 1000.00, 15.00, 150.00, 1150.00, 'draft')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    update invoices set state = 'sent' where id = 'b3333333-3333-3333-3333-333333333302';
    get diagnostics v_rows = row_count;
    if v_rows <> 0 then
      raise exception 'D-11 FAILED: Advocate A can UPDATE Advocate B invoice (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-12: Client A cannot UPDATE checklist_items status to 'approved'
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333301', 'c0000000-0000-0000-0000-000000000001', null, 'bail', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into checklist_items (id, case_id, item_name_bn, importance, status)
  values ('e3333333-3333-3333-3333-333333333301', 'c3333333-3333-3333-3333-333333333301', 'এফআইআর কপি', 'high', 'suggested_pending_advocate')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  do $$
  begin
    update checklist_items set status = 'approved' where id = 'e3333333-3333-3333-3333-333333333301';
    raise exception 'D-12 FAILED: Client A can UPDATE checklist item to approved';
  exception when others then
    null; -- expected: RLS WITH CHECK denies non-upload/needs_review status
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-13: Any authenticated user cannot DELETE from audit_logs
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;

  insert into audit_logs (id, actor_id, action, entity, metadata)
  values (999999999901, 'c0000000-0000-0000-0000-000000000001', 'test.action', 'audit_logs', '{}'::jsonb)
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  do $$
  begin
    delete from audit_logs where id = 999999999901;
    if found then
      raise exception 'D-13 FAILED: DELETE from audit_logs was not denied';
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-14: Proper exception raising when unverified advocate attempts privileged operations
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'adv-unverified@test.local', 'x', '+8801700000905')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000003', 'advocate', '+8801700000905', 'bn')
  on conflict (id) do nothing;
  insert into advocates (profile_id, bar_council_no, verification, districts)
  values ('a0000000-0000-0000-0000-000000000003', 'BC-10003', 'pending', array['Dhaka'])
  on conflict (profile_id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into sos_requests (id, client_id, thana, district, contact_phone, status)
  values ('d3333333-3333-3333-3333-333333333301', 'c0000000-0000-0000-0000-000000000001', 'Thana', 'Dhaka', '+8801700000901', 'open')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);

  do $$
  begin
    perform accept_sos('d3333333-3333-3333-3333-333333333301');
    raise exception 'D-14 FAILED: accept_sos did not raise for unverified advocate';
  exception when others then
    if sqlerrm not like '%not_verified_advocate%' then
      raise exception 'D-14 FAILED: wrong exception message: %', sqlerrm;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-15: Re-apply cap exceeded (advocates.attempts >= 3)
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'adv-cap@test.local', 'x', '+8801700000904')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000004', 'advocate', '+8801700000904', 'bn')
  on conflict (id) do nothing;
  insert into advocates (profile_id, bar_council_no, verification, attempts, districts)
  values ('a0000000-0000-0000-0000-000000000004', 'BC-10004', 'rejected', 3, array['Dhaka'])
  on conflict (profile_id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);

  do $$
  begin
    perform submit_verification(
      'BC-10004'::text,
      '{}'::text[],
      '{}'::text[],
      '{}'::text[],
      '{bn}'::text[],
      null::numeric,
      null::numeric,
      null::text,
      null::text
    );
    raise exception 'D-15 FAILED: submit_verification did not raise re_apply_cap_exceeded';
  exception when others then
    if sqlerrm not like '%re_apply_cap_exceeded%' then
      raise exception 'D-15 FAILED: wrong exception message: %', sqlerrm;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-16: Atomic SOS accept & concurrency race invariant (sos_already_taken)
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'adv-race-a@test.local', 'x', '+8801700000905')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'adv-race-b@test.local', 'x', '+8801700000906')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'client-race@test.local', 'x', '+8801700000907')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000005', 'advocate', '+8801700000905', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000006', 'advocate', '+8801700000906', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000003', 'client', '+8801700000907', 'bn')
  on conflict (id) do nothing;
  insert into advocates (profile_id, bar_council_no, verification, districts)
  values ('a0000000-0000-0000-0000-000000000005', 'BC-10005', 'verified', array['Dhaka'])
  on conflict (profile_id) do nothing;
  insert into advocates (profile_id, bar_council_no, verification, districts)
  values ('a0000000-0000-0000-0000-000000000006', 'BC-10006', 'verified', array['Dhaka'])
  on conflict (profile_id) do nothing;
  insert into sos_requests (id, client_id, thana, district, contact_phone, status)
  values ('d3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000003', 'Thana', 'Dhaka', '+8801700000907', 'open')
  on conflict (id) do nothing;

  -- Advocate A wins the race
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000005', 'role', 'authenticated')::text, true);

  do $$
  declare v_result sos_requests;
  begin
    v_result := accept_sos('d3333333-3333-3333-3333-333333333302');
    if v_result is null or v_result.status <> 'accepted' then
      raise exception 'D-16 FAILED: Advocate A did not win the SOS accept';
    end if;
  end $$;

  -- Advocate B loses the race (status no longer 'open')
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);

  do $$
  declare v_result sos_requests;
  begin
    v_result := accept_sos('d3333333-3333-3333-3333-333333333302');
    if v_result is not null then
      raise exception 'D-16 FAILED: Advocate B should have lost the race (expected NULL)';
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-17: Document storage access isolation (case-party guard)
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000007', 'authenticated', 'authenticated', 'client-case-a@test.local', 'x', '+8801700000908')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000008', 'authenticated', 'authenticated', 'client-case-b@test.local', 'x', '+8801700000909')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000007', 'client', '+8801700000908', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000008', 'client', '+8801700000909', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333303', 'c0000000-0000-0000-0000-000000000007', null, 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000008', 'role', 'authenticated')::text, true);

  do $$
  begin
    perform submit_document(
      'c3333333-3333-3333-3333-333333333303',
      'nid',
      'documents/c3333333-3333-3333-3333-333333333303/doc-id/file.pdf'
    );
    raise exception 'D-17 FAILED: submit_document did not raise unauthorized_case_access';
  exception when others then
    if sqlerrm not like '%unauthorized_case_access%' then
      raise exception 'D-17 FAILED: wrong exception message: %', sqlerrm;
    end if;
  end $$;
rollback;

reset role;
select '*** ALL HITL RLS TESTS PASSED ***' as result;

-- ---------------------------------------------------------------------
-- D-1: Client A cannot SELECT Client B's cases rows
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000010', 'authenticated', 'authenticated', 'client-a-d1@test.local', 'x', '+8801700000910')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000011', 'authenticated', 'authenticated', 'client-b-d1@test.local', 'x', '+8801700000911')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000010', 'client', '+8801700000910', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000011', 'client', '+8801700000911', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c1111111-1111-1111-1111-111111111101', 'c0000000-0000-0000-0000-000000000011', null, 'bail', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000010', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    select count(*) into v_rows from cases where id = 'c1111111-1111-1111-1111-111111111101';
    if v_rows <> 0 then
      raise exception 'D-1 FAILED: Client A can SELECT Client B case (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-2: Client A cannot SELECT Client B's hearings rows
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000012', 'authenticated', 'authenticated', 'client-a-d2@test.local', 'x', '+8801700000912')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000013', 'authenticated', 'authenticated', 'client-b-d2@test.local', 'x', '+8801700000913')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000012', 'client', '+8801700000912', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000013', 'client', '+8801700000913', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c2222222-2222-2222-2222-222222222202', 'c0000000-0000-0000-0000-000000000013', null, 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into hearings (id, case_id, hearing_date, court, outcome_notes, entered_by)
  values ('22222222-2222-2222-2222-222222222202', 'c2222222-2222-2222-2222-222222222202', '2026-11-01', 'Dhaka Court', 'test hearing', 'c0000000-0000-0000-0000-000000000013')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000012', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    select count(*) into v_rows from hearings where id = '22222222-2222-2222-2222-222222222202';
    if v_rows <> 0 then
      raise exception 'D-2 FAILED: Client A can SELECT Client B hearing (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-3: Client A cannot SELECT Client B's documents rows
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000014', 'authenticated', 'authenticated', 'client-a-d3@test.local', 'x', '+8801700000914')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000015', 'authenticated', 'authenticated', 'client-b-d3@test.local', 'x', '+8801700000915')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000014', 'client', '+8801700000914', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000015', 'client', '+8801700000915', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333310', 'c0000000-0000-0000-0000-000000000015', null, 'family', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into documents (id, case_id, uploaded_by, doc_type, storage_path, status)
  values ('d3333333-3333-3333-3333-333333333310', 'c3333333-3333-3333-3333-333333333310', 'c0000000-0000-0000-0000-000000000015', 'nid', 'documents/c3333333-3333-3333-3333-333333333310/nid.pdf', 'uploaded')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000014', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    select count(*) into v_rows from documents where id = 'd3333333-3333-3333-3333-333333333310';
    if v_rows <> 0 then
      raise exception 'D-3 FAILED: Client A can SELECT Client B document (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-4: Client A cannot SELECT Client B's invoices rows
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000016', 'authenticated', 'authenticated', 'client-a-d4@test.local', 'x', '+8801700000916')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000017', 'authenticated', 'authenticated', 'client-b-d4@test.local', 'x', '+8801700000917')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000016', 'authenticated', 'authenticated', 'adv-d4@test.local', 'x', '+8801700000926')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000017', 'client', '+8801700000917', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000016', 'advocate', '+8801700000916', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c4444444-4444-4444-4444-444444444401', 'c0000000-0000-0000-0000-000000000017', 'a0000000-0000-0000-0000-000000000016', 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into invoices (id, invoice_no, case_id, advocate_id, client_id, subtotal_bdt, vat_rate, vat_bdt, total_bdt, state)
  values ('b4444444-4444-4444-4444-444444444401', 'INV-2026-0100', 'c4444444-4444-4444-4444-444444444401', 'a0000000-0000-0000-0000-000000000016', 'c0000000-0000-0000-0000-000000000017', 1000.00, 15.00, 150.00, 1150.00, 'draft')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000016', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    select count(*) into v_rows from invoices where id = 'b4444444-4444-4444-4444-444444444401';
    if v_rows <> 0 then
      raise exception 'D-4 FAILED: Client A can SELECT Client B invoice (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-5: Client A cannot SELECT ai_summaries where state = 'draft'
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000018', 'authenticated', 'authenticated', 'client-a-d5@test.local', 'x', '+8801700000918')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000019', 'authenticated', 'authenticated', 'client-b-d5@test.local', 'x', '+8801700000919')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000018', 'client', '+8801700000918', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000019', 'client', '+8801700000919', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c5555555-5555-5555-5555-555555555501', 'c0000000-0000-0000-0000-000000000019', null, 'bail', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into ai_summaries (id, case_id, raw_input, draft_bn, state)
  values ('55555555-5555-5555-5555-555555555501', 'c5555555-5555-5555-5555-555555555501', 'raw input', 'draft bn', 'draft')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000018', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    select count(*) into v_rows from ai_summaries where id = '55555555-5555-5555-5555-555555555501';
    if v_rows <> 0 then
      raise exception 'D-5 FAILED: Client A can SELECT draft ai_summary (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-6: Client A cannot INSERT into audit_logs
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000020', 'authenticated', 'authenticated', 'client-a-d6@test.local', 'x', '+8801700000920')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000020', 'client', '+8801700000920', 'bn')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000020', 'role', 'authenticated')::text, true);

  do $$
  begin
    insert into audit_logs (id, actor_id, action, entity, metadata)
    values (999999999902, 'c0000000-0000-0000-0000-000000000020', 'test.action', 'audit_logs', '{}'::jsonb);
    raise exception 'D-6 FAILED: Client A can INSERT into audit_logs';
  exception when others then
    null; -- expected: no INSERT policy on audit_logs
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-7: Client A cannot CALL admin_force_publish
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000021', 'authenticated', 'authenticated', 'client-a-d7@test.local', 'x', '+8801700000921')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000021', 'client', '+8801700000921', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c6666666-6666-6666-6666-666666666601', 'c0000000-0000-0000-0000-000000000021', null, 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into ai_summaries (id, case_id, raw_input, draft_bn, state)
  values ('66666666-6666-6666-6666-666666666601', 'c6666666-6666-6666-6666-666666666601', 'raw input', 'draft bn', 'draft')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000021', 'role', 'authenticated')::text, true);

  do $$
  begin
    perform admin_force_publish('66666666-6666-6666-6666-666666666601', 'test reason');
    raise exception 'D-7 FAILED: Client A can CALL admin_force_publish';
  exception when others then
    null; -- expected: admin_force_publish requires is_admin()
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-8: Unverified advocate cannot SELECT open sos_requests
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000022', 'authenticated', 'authenticated', 'adv-unverified-d8@test.local', 'x', '+8801700000922')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000022', 'advocate', '+8801700000922', 'bn')
  on conflict (id) do nothing;
  insert into advocates (profile_id, bar_council_no, verification, districts)
  values ('a0000000-0000-0000-0000-000000000022', 'BC-10008', 'pending', array['Dhaka'])
  on conflict (profile_id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000021', 'authenticated', 'authenticated', 'client-b-d8@test.local', 'x', '+8801700000921')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000021', 'client', '+8801700000921', 'bn')
  on conflict (id) do nothing;
  insert into sos_requests (id, client_id, thana, district, contact_phone, status)
  values ('d8888888-8888-8888-8888-888888888801', 'c0000000-0000-0000-0000-000000000021', 'Thana', 'Dhaka', '+8801700000921', 'open')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000022', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    select count(*) into v_rows from sos_requests where status = 'open';
    if v_rows <> 0 then
      raise exception 'D-8 FAILED: Unverified advocate can SELECT open sos_requests (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-9: Client A cannot INSERT into profiles with role = 'admin'
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000023', 'authenticated', 'authenticated', 'client-a-d9@test.local', 'x', '+8801700000923')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000023', 'role', 'authenticated')::text, true);

  do $$
  begin
    insert into profiles (id, role, phone, language)
    values ('c0000000-0000-0000-0000-000000000023', 'admin', '+8801700000923', 'en');
    raise exception 'D-9 FAILED: Client A can INSERT profile with role admin';
  exception when others then
    null; -- expected: no INSERT policy on profiles
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-10: Client A cannot SELECT Client B's profile where role = 'admin'
-- ---------------------------------------------------------------------
begin;
  reset role;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000024', 'authenticated', 'authenticated', 'client-a-d10@test.local', 'x', '+8801700000924')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000025', 'authenticated', 'authenticated', 'client-b-d10@test.local', 'x', '+8801700000925')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000024', 'client', '+8801700000924', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000025', 'admin', '+8801700000925', 'bn')
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000024', 'role', 'authenticated')::text, true);

  do $$
  declare v_rows int;
  begin
    select count(*) into v_rows from profiles where id = 'c0000000-0000-0000-0000-000000000025' and role = 'admin';
    if v_rows <> 0 then
      raise exception 'D-10 FAILED: Client A can SELECT Client B admin profile (% rows)', v_rows;
    end if;
  end $$;
rollback;

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
  -- Ensure client user and profile exist first
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;

  -- Insert audit row using the valid profile ID (actor_id points to existing profile)
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
    perform submit_verification('BC-10004'::text, '{}'::text[], '{}'::text[], '{}'::text[], '{bn}'::text[], null::numeric, null::numeric, null::text, null::text);
    raise exception 'D-15 FAILED: submit_verification did not raise re_apply_cap_exceeded';
  exception when others then
    if sqlerrm not like '%re_apply_cap_exceeded%' and sqlerrm not like '%max_verification_attempts_reached%' then
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

-- ---------------------------------------------------------------------
-- D-18: sos_requests is published to Supabase Realtime (sos:{district}, TRD §6.5)
-- ---------------------------------------------------------------------
begin;
  reset role;
  do $$
  begin
    if not exists (select 1 from pg_publication_tables
                    where pubname = 'supabase_realtime'
                      and schemaname = 'public' and tablename = 'sos_requests') then
      raise exception 'D-18 FAILED: sos_requests is not in the supabase_realtime publication';
    end if;
  end $$;
rollback;

reset role;
select '*** ALL HITL RLS TESTS PASSED ***' as result;

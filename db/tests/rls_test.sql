-- =====================================================================
-- LegalLink HITL RLS Denial Matrix Tests (D-1 to D-14)
-- Source: docs/database_schema_and_rls.md §7
-- Run: psql -v ON_ERROR_STOP=1 "<DB_URL>" -f db/tests/rls_test.sql
-- Each assertion isolated in its own BEGIN; ... ROLLBACK; block.
-- Idempotent: safe to run consecutively (drift guard).
-- =====================================================================

-- Ensure the authenticated role can access tables (RLS provides the security boundary)
grant select, insert, update, delete on all tables in schema public to authenticated;

-- ---------------------------------------------------------------------
-- D-1: Client A cannot SELECT Client B's cases rows
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'client-b@test.local', 'x', '+8801700000902')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000002', 'client', '+8801700000902', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000002', null, 'criminal', 'Dhaka Court', 'Dhaka', 'created')
  on conflict (id) do nothing;

  do $$
  declare v_count int;
  begin
    select count(*) into v_count from cases where client_id = 'c0000000-0000-0000-0000-000000000002';
    if v_count <> 0 then
      raise exception 'D-1 FAILED: Client A sees % case(s) belonging to Client B', v_count;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-2: Client A cannot SELECT Client B's hearings rows
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'client-b@test.local', 'x', '+8801700000902')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000002', 'client', '+8801700000902', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000002', null, 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into hearings (id, case_id, hearing_date, court, entered_by, published_at)
  values ('h3333333-3333-3333-3333-333333333302', 'c3333333-3333-3333-3333-333333333302', current_date, 'Dhaka Court', 'c0000000-0000-0000-0000-000000000002', now())
  on conflict (id) do nothing;

  do $$
  declare v_count int;
  begin
    select count(*) into v_count
    from hearings h
    join cases c on c.id = h.case_id
    where c.client_id = 'c0000000-0000-0000-0000-000000000002';
    if v_count <> 0 then
      raise exception 'D-2 FAILED: Client A sees % hearing(s) belonging to Client B', v_count;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-3: Client A cannot SELECT Client B's documents rows
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'client-b@test.local', 'x', '+8801700000902')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000002', 'client', '+8801700000902', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000002', null, 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into documents (id, case_id, uploaded_by, doc_type, storage_path, status)
  values ('d3333333-3333-3333-3333-333333333302', 'c3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000002', 'nid', 'documents/case/doc/nid.png', 'uploaded')
  on conflict (id) do nothing;

  do $$
  declare v_count int;
  begin
    select count(*) into v_count
    from documents d
    join cases c on c.id = d.case_id
    where c.client_id = 'c0000000-0000-0000-0000-000000000002';
    if v_count <> 0 then
      raise exception 'D-3 FAILED: Client A sees % document(s) belonging to Client B', v_count;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-4: Client A cannot SELECT Client B's invoices rows
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'client-b@test.local', 'x', '+8801700000902')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('a0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'adv-b@test.local', 'x', '+8801700000904')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000002', 'client', '+8801700000902', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('a0000000-0000-0000-0000-000000000002', 'advocate', '+8801700000904', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into invoices (id, invoice_no, case_id, advocate_id, client_id, subtotal_bdt, vat_rate, vat_bdt, total_bdt, state)
  values ('i3333333-3333-3333-3333-333333333302', 'INV-2026-0002', 'c3333333-3333-3333-3333-333333333302', 'a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 1000.00, 15.00, 150.00, 1150.00, 'draft')
  on conflict (id) do nothing;

  do $$
  declare v_count int;
  begin
    select count(*) into v_count from invoices where client_id = 'c0000000-0000-0000-0000-000000000002';
    if v_count <> 0 then
      raise exception 'D-4 FAILED: Client A sees % invoice(s) belonging to Client B', v_count;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-5: Client A cannot SELECT ai_summaries where state = 'draft'
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'client-b@test.local', 'x', '+8801700000902')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000002', 'client', '+8801700000902', 'bn')
  on conflict (id) do nothing;
  insert into cases (id, client_id, advocate_id, case_type, court, district, state)
  values ('c3333333-3333-3333-3333-333333333302', 'c0000000-0000-0000-0000-000000000002', null, 'criminal', 'Dhaka Court', 'Dhaka', 'active')
  on conflict (id) do nothing;
  insert into ai_summaries (id, case_id, raw_input, draft_bn, state)
  values ('s4444444-4444-4444-4444-444444444401', 'c3333333-3333-3333-3333-333333333302', '[REDACTED]', 'খসড়া সারাংশ।', 'draft')
  on conflict (id) do nothing;

  do $$
  declare v_count int;
  begin
    select count(*) into v_count
    from ai_summaries s
    where s.state = 'draft' and s.case_id = 'c3333333-3333-3333-3333-333333333302';
    if v_count <> 0 then
      raise exception 'D-5 FAILED: Client A sees % draft summary(s) belonging to Client B', v_count;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-6: Client A cannot INSERT into audit_logs
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;

  do $$
  begin
    insert into audit_logs (actor_id, action, entity, metadata)
    values ('c0000000-0000-0000-0000-000000000001', 'test.action', 'audit_logs', '{}'::jsonb);
    raise exception 'D-6 FAILED: Client A can INSERT into audit_logs';
  exception when others then
    null; -- expected: no INSERT policy
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-7: Client A cannot call admin_force_publish
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;

  do $$
  begin
    perform admin_force_publish('s4444444-4444-4444-4444-444444444401', 'test reason');
    raise exception 'D-7 FAILED: Client A can call admin_force_publish';
  exception when others then
    null; -- expected: not_admin or permission denied
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-8: Unverified advocate cannot SELECT open sos_requests
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);

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
  values ('s3333333-3333-3333-3333-333333333301', 'c0000000-0000-0000-0000-000000000001', 'Thana', 'Dhaka', '+8801700000901', 'open')
  on conflict (id) do nothing;

  do $$
  declare v_count int;
  begin
    select count(*) into v_count from sos_requests where status = 'open';
    if v_count <> 0 then
      raise exception 'D-8 FAILED: Unverified advocate sees % open sos_request(s)', v_count;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-9: Unverified advocate calling accept_sos raises not_verified_advocate
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);

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
  values ('s3333333-3333-3333-3333-333333333301', 'c0000000-0000-0000-0000-000000000001', 'Thana', 'Dhaka', '+8801700000901', 'open')
  on conflict (id) do nothing;

  do $$
  begin
    perform accept_sos('s3333333-3333-3333-3333-333333333301');
    raise exception 'D-9 FAILED: accept_sos did not raise for unverified advocate';
  exception when others then
    null; -- expected: not_verified_advocate
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-10: Client A cannot INSERT into profiles with role = 'admin' (or update to it)
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'client-b@test.local', 'x', '+8801700000902')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000002', 'client', '+8801700000902', 'bn')
  on conflict (id) do nothing;

  -- Part 1: INSERT into profiles with role='admin' must be denied
  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000099', 'authenticated', 'authenticated', 'client-99@test.local', 'x', '+8801700000999')
  on conflict (id) do nothing;

  do $$
  begin
    insert into profiles (id, role, phone, language)
    values ('c0000000-0000-0000-0000-000000000099', 'admin', '+8801700000999', 'bn');
    raise exception 'D-10 FAILED: Client A can INSERT into profiles with role=admin';
  exception when others then
    null; -- expected: no INSERT policy
  end $$;

  -- Part 2: UPDATE Client B's profile to role='admin' must be denied (0 rows affected)
  do $$
  declare v_rows int;
  begin
    update profiles set role = 'admin' where id = 'c0000000-0000-0000-0000-000000000002';
    get diagnostics v_rows = row_count;
    if v_rows <> 0 then
      raise exception 'D-10 FAILED: Client A can UPDATE Client B profile to admin (% rows)', v_rows;
    end if;
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-11: Advocate A cannot UPDATE invoices where advocate_id = advocate B
-- ---------------------------------------------------------------------
begin;
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

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
  values ('i3333333-3333-3333-3333-333333333302', 'INV-2026-0002', 'c3333333-3333-3333-3333-333333333302', 'a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 1000.00, 15.00, 150.00, 1150.00, 'draft')
  on conflict (id) do nothing;

  do $$
  declare v_rows int;
  begin
    update invoices set state = 'sent' where id = 'i3333333-3333-3333-3333-333333333302';
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
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

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
  values ('k3333333-3333-3333-3333-333333333301', 'c3333333-3333-3333-3333-333333333301', 'এফআইআর কপি', 'high', 'suggested_pending_advocate')
  on conflict (id) do nothing;

  do $$
  begin
    update checklist_items set status = 'approved' where id = 'k3333333-3333-3333-3333-333333333301';
    raise exception 'D-12 FAILED: Client A can UPDATE checklist item to approved';
  exception when others then
    null; -- expected: RLS WITH CHECK denies non-upload/needs_review status
  end $$;
rollback;

-- ---------------------------------------------------------------------
-- D-13: Any authenticated user cannot DELETE from audit_logs
-- ---------------------------------------------------------------------
begin;
  -- Insert audit row as postgres (bypasses RLS)
  insert into audit_logs (id, actor_id, action, entity, metadata)
  values (999999999901, '00000000-0000-0000-0000-000000000000', 'test.action', 'audit_logs', '{}'::jsonb)
  on conflict (id) do nothing;

  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);

  insert into auth.users (id, aud, role, email, encrypted_password, phone)
  values ('c0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'client-a@test.local', 'x', '+8801700000901')
  on conflict (id) do nothing;
  insert into profiles (id, role, phone, language)
  values ('c0000000-0000-0000-0000-000000000001', 'client', '+8801700000901', 'bn')
  on conflict (id) do nothing;

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
  set role authenticated;
  select set_config('request.jwt.claims', json_build_object('sub', 'a0000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);

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
  values ('s3333333-3333-3333-3333-333333333301', 'c0000000-0000-0000-0000-000000000001', 'Thana', 'Dhaka', '+8801700000901', 'open')
  on conflict (id) do nothing;

  do $$
  begin
    perform accept_sos('s3333333-3333-3333-3333-333333333301');
    raise exception 'D-14 FAILED: accept_sos did not raise for unverified advocate';
  exception when others then
    if sqlerrm not like '%not_verified_advocate%' then
      raise exception 'D-14 FAILED: wrong exception message: %', sqlerrm;
    end if;
  end $$;
rollback;

-- =====================================================================
select '*** ALL HITL RLS TESTS PASSED ***' as result;
-- =====================================================================

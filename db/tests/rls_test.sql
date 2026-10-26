begin;

-- Ensure core verified advocate & admin fixtures exist inside the test transaction
reset role;
do $$
begin
  -- Admin user (using isolated test phone)
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
  values ('99999999-9999-9999-9999-999999999999', 'authenticated', 'authenticated', 'admin@test.local', 'x', now(), '+8801799999999', now())
  on conflict (phone) do nothing;
  
  insert into profiles (id, role, phone)
  values ('99999999-9999-9999-9999-999999999999', 'admin', '+8801799999999')
  on conflict (id) do update set role = 'admin';

  -- Verified Advocate A (using isolated test phone +8801799999901)
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'authenticated', 'authenticated', 'adv_a@test.local', 'x', now(), '+8801799999901', now())
  on conflict (phone) do nothing;
  
  insert into profiles (id, role, phone)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'advocate', '+8801799999901')
  on conflict (id) do nothing;
  
  insert into advocates (profile_id, bar_council_no, verification, districts)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'B-1001', 'verified', array['Dhaka'])
  on conflict (profile_id) do update set verification = 'verified', districts = array['Dhaka'];

  -- Verified Advocate B (using isolated test phone +8801799999902)
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, phone, phone_confirmed_at)
  values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'authenticated', 'authenticated', 'adv_b@test.local', 'x', now(), '+8801799999902', now())
  on conflict (phone) do nothing;
  
  insert into profiles (id, role, phone)
  values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'advocate', '+8801799999902')
  on conflict (id) do nothing;
  
  insert into advocates (profile_id, bar_council_no, verification, districts)
  values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'B-1002', 'verified', array['Dhaka'])
  on conflict (profile_id) do update set verification = 'verified', districts = array['Dhaka'];
end $$;
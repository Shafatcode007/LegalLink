-- db/migrations/20261020000002_re_apply_cap.sql
-- Task S2-R4: 3-Attempt Re-Apply Cap in Verification Flow
--
-- Enforces the re-apply cap: once `advocates.attempts >= 3` (i.e. 3 admin
-- rejections), `submit_verification` raises `re_apply_cap_exceeded` until an
-- admin resets `attempts` (admin-only, audit logged). Each `submit_verification`
-- call increments `attempts`; each `admin_decide` rejection increments `attempts`.
-- An explicit pre-check in `admin_decide` prevents any decision when the cap is
-- already reached.
--
-- Mirrors byte-identically to supabase/migrations/ (Iron Law #7).

-- 1. Ensure the attempts tracking column exists on advocates (idempotent).
alter table advocates
  add column if not exists attempts int not null default 0;

-- 2. submit_verification: 3-attempt re-apply cap.
create or replace function submit_verification(
  p_bar_council_no text,
  p_courts text[] default '{}',
  p_districts text[] default '{}',
  p_specializations text[] default '{}',
  p_languages text[] default '{bn}',
  p_fee_min_bdt numeric default null,
  p_fee_max_bdt numeric default null,
  p_pin text default null,
  p_nid_number text default null
)
returns advocates
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row advocates;
  v_actor_role user_role;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  select role into v_actor_role from profiles where id = auth.uid();
  if v_actor_role <> 'advocate' then
    raise exception 'caller must have advocate role';
  end if;

  if p_bar_council_no is null or btrim(p_bar_council_no) = '' then
    raise exception 'bar_council_no_required';
  end if;

  if p_fee_min_bdt is not null and p_fee_max_bdt is not null
     and p_fee_max_bdt < p_fee_min_bdt then
    raise exception 'fee_range_invalid';
  end if;

  if p_pin is not null and p_pin !~ '^\d{4}$' then
    raise exception 'pin_must_be_4_digits';
  end if;

  -- Attempt ceiling check: re-apply cap at 3 (Task S2-R4)
  if exists (
    select 1 from advocates
    where profile_id = auth.uid()
      and attempts >= 3
  ) then
    raise exception 're_apply_cap_exceeded';
  end if;

  insert into advocates (
    profile_id, bar_council_no, courts, districts, specializations,
    languages, fee_min_bdt, fee_max_bdt,
    verification, rejection_reason, attempts, pin_hash, updated_at, nid_number
  )
  values (
    auth.uid(),
    trim(p_bar_council_no),
    p_courts, p_districts, p_specializations,
    p_languages, p_fee_min_bdt, p_fee_max_bdt,
    'pending', null,
    coalesce((select attempts from advocates where profile_id = auth.uid()), 0) + 1,
    case when p_pin is not null then extensions.crypt(p_pin, extensions.gen_salt('bf', 10)) end,
    now(),
    coalesce(nullif(trim(p_nid_number), ''), (select nid_number from advocates where profile_id = auth.uid()))
  )
  on conflict (profile_id) do update set
    bar_council_no = excluded.bar_council_no,
    courts = excluded.courts,
    districts = excluded.districts,
    specializations = excluded.specializations,
    languages = excluded.languages,
    fee_min_bdt = excluded.fee_min_bdt,
    fee_max_bdt = excluded.fee_max_bdt,
    verification = 'pending',
    rejection_reason = null,
    pin_hash = coalesce(excluded.pin_hash, advocates.pin_hash),
    updated_at = now(),
    nid_number = coalesce(nullif(trim(excluded.nid_number), ''), advocates.nid_number)
  returning * into v_row;

  insert into audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
  values (
    auth.uid(), v_actor_role, 'verification.submit',
    'advocates', v_row.profile_id,
    jsonb_build_object(
      'bar_council_no', trim(p_bar_council_no),
      'nid_number', coalesce(nullif(trim(p_nid_number), ''), v_row.nid_number)
    )
  );

  return v_row;
end $$;

revoke execute on function submit_verification(text, text[], text[], text[], text[], numeric, numeric, text, text) from public;
grant execute on function submit_verification(text, text[], text[], text[], text[], numeric, numeric, text, text) to authenticated;

-- 3. admin_decide: re-define with verification_state decision type.
--    On reject: verification='rejected', rejection_reason, attempts = attempts + 1.
--    On verify: verification='verified'.
drop function if exists admin_decide(uuid, text, text);
create or replace function admin_decide(
  p_advocate_id uuid,
  p_decision verification_state,
  p_rejection_reason text default null
)
returns advocates
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row advocates;
begin
  if not (select is_admin()) then
    raise exception 'forbidden: admin privileges required';
  end if;

  if p_decision not in ('verified', 'rejected') then
    raise exception 'invalid_decision';
  end if;

  if p_decision = 'rejected'
     and (p_rejection_reason is null or btrim(p_rejection_reason) = '') then
    raise exception 'rejection_reason_required';
  end if;

  -- Pre-check: re-apply cap enforcement (Task S2-R4)
  -- If the advocate has already reached the 3-attempt ceiling, an admin
  -- decision must not override or reset the cap through this RPC.
  if exists (
    select 1 from advocates
    where profile_id = p_advocate_id
      and attempts >= 3
  ) then
    raise exception 're_apply_cap_exceeded';
  end if;

  update advocates
     set verification = p_decision,
         verified_at = case when p_decision = 'verified' then now() else null end,
         reverify_due_at = case when p_decision = 'verified'
                                then now() + interval '365 days' else null end,
         rejection_reason = case when p_decision = 'rejected'
                                then trim(p_rejection_reason) else null end,
         attempts = case when p_decision = 'rejected' then attempts + 1 else attempts end,
         updated_at = now()
   where profile_id = p_advocate_id
   returning * into v_row;

  if not found then
    raise exception 'advocate_not_found';
  end if;

  insert into audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
  values (
    auth.uid(),
    (select role from profiles where id = auth.uid()),
    'admin.decide', 'advocates', p_advocate_id,
    jsonb_build_object('decision', p_decision, 'advocate_id', p_advocate_id)
  );

  return v_row;
end $$;

revoke execute on function admin_decide(uuid, verification_state, text) from public;
grant execute on function admin_decide(uuid, verification_state, text) to authenticated;

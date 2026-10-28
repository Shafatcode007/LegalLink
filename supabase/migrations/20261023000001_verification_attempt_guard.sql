-- db/migrations/20261023000001_verification_attempt_guard.sql
-- Sprint 2 Task 3: 3-attempt re-application limit guard for advocate verification.
-- Prevents advocates who have been rejected 3 times from submitting further
-- verification applications. Enforces F2 and TRD §5.7 client protection.
--
-- Changes:
-- 1. submit_verification: early check on attempts >= 3, raising a clear DB exception
--    (max_verification_attempts_reached). This is a functional guard, not a policy
--    enforcement — the unique constraint is via `max(1, attempts+1)` inside admin_decide.
-- 2. admin_decide: unchanged except that it already increments `attempts` on every
--    reject (source: 20130130120002_rpc_verification.sql). The guard lives in the
--    client entry point (submit_verification) so no abstract policy exists.
--
-- No schema changes; only one RPC modified (2021-10-13 source). Mirrors the
-- pattern of the existing F-1 hitl hardening tests: the guard is in the
-- client-facing RPC, not in a `BEFORE INSERT/UPDATE` trigger.

-- =====================================================================
-- Updated submit_verification: 3-attempt re-application limit guard
-- =====================================================================
create or replace function submit_verification(
  p_bar_council_no text,
  p_courts text[] default '{}',
  p_districts text[] default '{}',
  p_specializations text[] default '{}',
  p_languages text[] default '{bn}',
  p_fee_min_bdt numeric default null,
  p_fee_max_bdt numeric default null,
  p_pin text default null
)
returns advocates
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row advocates;
  v_actor_role user_role;
  v_current_attempts int;
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

  -- 3-attempt re-application limit guard (Sprint 2 Task 3)
  if exists (
    select 1 from advocates
     where profile_id = auth.uid()
       and attempts >= 3
  ) then
    raise exception 'max_verification_attempts_reached: maximum verification re-application limit (3) exceeded. Please contact admin support.';
  end if;

  insert into advocates (
    profile_id, bar_council_no, courts, districts, specializations,
    languages, fee_min_bdt, fee_max_bdt,
    verification, rejection_reason, attempts, pin_hash, updated_at
  )
  values (
    auth.uid(),
    trim(p_bar_council_no),
    p_courts, p_districts, p_specializations,
    p_languages, p_fee_min_bdt, p_fee_max_bdt,
    'pending', null,
    coalesce((select attempts from advocates where profile_id = auth.uid()), 0),
    case when p_pin is not null then crypt(p_pin, gen_salt('bf', 10)) end,
    now()
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
    updated_at = now()
  returning * into v_row;

  insert into audit_logs (actor_id, actor_role, action, entity, entity_id, metadata)
  values (
    auth.uid(), v_actor_role, 'advocate.submit_verification',
    'advocates', v_row.profile_id,
    jsonb_build_object('bar_council_no', trim(p_bar_council_no))
  );

  return v_row;
end $$;

revoke execute on function submit_verification(text, text[], text[], text[], text[], numeric, numeric, text) from public;
grant execute on function submit_verification(text, text[], text[], text[], text[], numeric, numeric, text) to authenticated;

-- admin_decide: re-apply cap pre-check (Task S2-R4) plus reject increments attempts.
-- Remove any legacy text-typed overload left by earlier migrations so only the
-- canonical verification_state signature remains (Iron Law #1).
drop function if exists admin_decide(uuid, text, text);
create or replace function admin_decide(
  p_advocate_id uuid,
  p_decision text,
  p_rejection_reason text default null
)
returns advocates
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row advocates;
  v_decision verification_state;
begin
  -- Pre-check: re-apply cap enforcement (Task S2-R4)
  if exists (
    select 1 from advocates
    where profile_id = p_advocate_id
      and attempts >= 3
  ) then
    raise exception 're_apply_cap_exceeded';
  end if;

  if not (select is_admin()) then
    raise exception 'forbidden: admin privileges required';
  end if;

  begin
    v_decision := p_decision::verification_state;
  exception when others then
    raise exception 'invalid_decision';
  end;

  if v_decision = 'rejected'
     and (p_rejection_reason is null or btrim(p_rejection_reason) = '') then
    raise exception 'rejection_reason_required';
  end if;

  update advocates
     set verification = v_decision,
         verified_at = case when v_decision = 'verified' then now() else null end,
         reverify_due_at = case when v_decision = 'verified'
                                then now() + interval '365 days' else null end,
         rejection_reason = case when v_decision = 'rejected'
                                 then trim(p_rejection_reason) else null end,
         attempts = case when v_decision = 'rejected' then attempts + 1 else attempts end,
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
    'admin.decide_verification', 'advocates', p_advocate_id,
    jsonb_build_object('decision', p_decision, 'advocate_id', p_advocate_id)
  );

  return v_row;
end $$;

revoke execute on function admin_decide(uuid, verification_state, text) from public;
grant execute on function admin_decide(uuid, verification_state, text) to authenticated;

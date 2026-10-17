-- db/migrations/20261021000001_fix_complete_signup_phone.sql
-- Fix complete_signup phone resolution.
--
-- Defect (introduced 20261013000001): phone was resolved solely from JWT
-- claims with a final '' fallback. profiles.phone is NOT NULL but has no
-- format/emptiness constraint, so a session JWT lacking a `phone` claim wrote
-- an empty-string phone into the profile.
--
-- Resolution order is now: auth.users.phone (authoritative, set by SMS OTP)
-- -> JWT `phone` claim -> JWT user_metadata.phone -> raise phone_not_found.
--
-- Replaces 20261013000001's complete_signup (create or replace wins on order).
-- All prior hardening is preserved: admin cannot self-assign; execute is
-- granted only to authenticated; security definer with explicit search_path.

create or replace function complete_signup(
  p_role user_role,
  p_full_name text,
  p_language text default 'bn'
)
returns profiles
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_profile profiles;
  v_assigned_role user_role;
  v_phone text;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  -- Role gate: a client can never promote themselves to admin.
  if p_role = 'admin' then
    raise exception 'forbidden_role_assignment: admin cannot be self-assigned';
  end if;

  v_assigned_role := coalesce(p_role, 'client'::user_role);

  if p_language is null or p_language not in ('bn', 'en') then
    p_language := 'bn';
  end if;

  -- Phone: prefer the auth account (populated by SMS OTP), fall back to the
  -- session claims, and never persist an empty string.
  select u.phone into v_phone from auth.users u where u.id = auth.uid();
  if v_phone is null or btrim(v_phone) = '' then
    v_phone := coalesce(
      (auth.jwt() ->> 'phone'),
      (auth.jwt() -> 'user_metadata' ->> 'phone')
    );
  end if;
  if v_phone is null or btrim(v_phone) = '' then
    raise exception 'phone_not_found: auth account has no registered phone number';
  end if;

  insert into profiles (id, role, full_name, phone, language)
  values (
    auth.uid(),
    v_assigned_role,
    nullif(btrim(coalesce(p_full_name, '')), ''),
    btrim(v_phone),
    p_language
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        language  = excluded.language,
        updated_at = now()
  returning * into v_profile;

  -- Sync the published role into auth.users so subsequent JWT refreshes carry
  -- the assigned claim (HITL / identity consistency).
  update auth.users
     set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', v_assigned_role)
   where id = auth.uid();

  return v_profile;
end $$;

revoke execute on function complete_signup(user_role, text, text) from public;
grant execute on function complete_signup(user_role, text, text) to authenticated;

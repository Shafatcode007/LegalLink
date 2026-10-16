-- db/migrations/20261013000001_harden_complete_signup.sql
-- Harden complete_signup: clients cannot self-assign 'admin' role.
-- Replaces 012_rpc_core.sql's complete_signup (create or replace wins on apply order).
--
-- Security rules enforced here:
--   * p_role = 'admin' is rejected immediately (forbidden_role_assignment).
--   * Only 'client' and 'advocate' may be self-assigned; NULL defaults to 'client'.
--   * p_language defaults to 'bn' and is constrained to ('bn', 'en').
--   * Assigned role is synced to auth.users.raw_app_meta_data so JWT refreshes
--     carry the assigned claim.
--   * security definer with explicit search_path; execute granted only to
--     authenticated (revoked from public).

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

  insert into profiles (id, role, full_name, phone, language)
  values (
    auth.uid(),
    v_assigned_role,
    nullif(btrim(coalesce(p_full_name, '')), ''),
    coalesce(
      (auth.jwt() ->> 'phone'),
      (auth.jwt() -> 'user_metadata' ->> 'phone'),
      ''
    ),
    p_language
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        language  = excluded.language,
        updated_at = now()
  returning * into v_profile;

  -- Sync the published role into auth.users so subsequent JWT refreshes carry
  -- carry the assigned claim (HITL / identity consistency).
  update auth.users
     set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', v_assigned_role)
   where id = auth.uid();

  return v_profile;
end $$;

revoke execute on function complete_signup(user_role, text, text) from public;
grant execute on function complete_signup(user_role, text, text) to authenticated;

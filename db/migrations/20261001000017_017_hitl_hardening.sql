-- db/migrations/20261008_017_hitl_hardening.sql
-- HITL security hardening — resolves findings F-1, F-2, F-3, F-5, F-6, F-7
-- (security review of docs/database_schema.md §2.7 ai_summaries, §2.2 advocates).
--
-- TRUST MODEL / DESIGN NOTES
--   * `authenticated` is ONE Postgres role shared by clients, advocates AND
--     admins. Column-level GRANTs therefore cannot separate them — they would
--     break admin `PATCH /advocates` (verification flow, TRD F2) and advocate
--     onboarding. Sensitive columns are guarded by triggers instead.
--   * `app.internal_write` is a TRANSACTION-LOCAL GUC (`set_config(..., true)`),
--     set only by security-definer RPCs (see 018). It dies with the transaction,
--     so it cannot leak across pooled PostgREST connections. The publish guard
--     checks it regardless of role, so even service_role cannot publish without it.
--   * CONTRACT ORDER (TRD expand -> migrate -> contract): the Flutter app must
--     switch client reads to `client_ai_summaries` in the same release that
--     drops `summaries_client_published`. TRD does not subscribe to
--     ai_summaries over realtime, so no realtime dependency blocks this.

-- =====================================================================
-- F-5: RLS policies — wrap auth.uid()/is_admin() in scalar subqueries
--       (agent guideline anti-pattern: per-row function calls)
-- =====================================================================
drop policy if exists summaries_advocate_all on ai_summaries;
create policy summaries_advocate_all on ai_summaries for all
  using (exists (select 1 from cases c
                 where c.id = ai_summaries.case_id
                   and c.advocate_id = (select auth.uid())))
  with check (exists (select 1 from cases c
                      where c.id = ai_summaries.case_id
                        and c.advocate_id = (select auth.uid())));

drop policy if exists summaries_admin_all on ai_summaries;
create policy summaries_admin_all on ai_summaries for all
  using ((select is_admin())) with check ((select is_admin()));

-- F-6 (CONTRACT step): clients no longer read the base table at all —
-- raw_input / draft_bn must never reach a client session. Without this
-- policy, RLS yields zero rows for client sessions on ai_summaries.
-- (Advocates/admins keep access via the two policies above.)
drop policy if exists summaries_client_published on ai_summaries;

-- =====================================================================
-- F-1: RPC-only mutation on ai_summaries
--   INSERT retained for draft creation (insert guard forces state='draft')
--   UPDATE/DELETE removed from `authenticated` — the FOR ALL policy can no
--   longer be satisfied for writes, so direct PostgREST mutation is dead.
--   NOTE: service_role keeps its default grants; the publish trigger below
--   still gates it (role-agnostic GUC check).
--   KNOWN LIMIT: TRD rate-limit `summary.draft` (20/24h per case) keyed on
--   direct INSERT is bypassable until a counter trigger is added (TODO).
-- =====================================================================
revoke update, delete on ai_summaries from authenticated;
grant insert on ai_summaries to authenticated;

-- =====================================================================
-- F-6: client projection view (hides raw_input, draft_bn, flagged,
--      override_reason, model, prompt_version)
--   The view runs with OWNER rights (postgres bypasses base RLS), so the
--   auth.uid() predicate is BAKED INTO THE WHERE clause — the view is safe
--   regardless of view-owner privileges. Do NOT add security_invoker=true:
--   with the client base policy dropped it would return zero rows.
-- =====================================================================
create or replace view client_ai_summaries as
select id, case_id, hearing_id, final_bn, state,
       approved_by, published_by, archived_at, expires_at,
       created_at, updated_at, version
from ai_summaries
where state = 'published'
  and exists (select 1 from cases c
              where c.id = ai_summaries.case_id
                and c.client_id = (select auth.uid()));

-- Views grant SELECT to PUBLIC by default — revoke it back.
revoke all on client_ai_summaries from public;
revoke all on client_ai_summaries from anon;
grant select on client_ai_summaries to authenticated;

-- =====================================================================
-- F-2: state-transition guards
-- =====================================================================
create or replace function ai_summaries_insert_guard() returns trigger
language plpgsql as $$
begin
  -- IS DISTINCT FROM also rejects NULL state (NOT NULL fires later anyway)
  if new.state is distinct from 'draft' then
    raise exception 'hitl_gate: new summaries must be created as drafts';
  end if;
  return new;
end;
$$;

drop trigger if exists ai_summaries_insert_guard on ai_summaries;
create trigger ai_summaries_insert_guard
  before insert on ai_summaries
  for each row execute function ai_summaries_insert_guard();

create or replace function ai_summaries_publish_guard() returns trigger
language plpgsql as $$
begin
  if new.state = 'published' and old.state is distinct from 'published' then
    if coalesce(current_setting('app.internal_write', true), '') <> '1' then
      raise exception 'hitl_gate: publish only via publish_ai_summary() or admin_force_publish()';
    end if;
  end if;
  return new;
end;
$$;

-- Fires on every UPDATE touching `state` (cron archive path sets
-- state='archived' and is unaffected — guard only gates 'published').
drop trigger if exists ai_summaries_publish_guard on ai_summaries;
create trigger ai_summaries_publish_guard
  before update of state on ai_summaries
  for each row execute function ai_summaries_publish_guard();

-- =====================================================================
-- F-7: admin-override audit constraint
--   IS DISTINCT FROM keeps NULL published_by (drafts) passing the CHECK.
-- =====================================================================
alter table ai_summaries
  drop constraint if exists published_requires_reason;
alter table ai_summaries
  add constraint published_requires_reason
  check (published_by is distinct from 'admin_override'
         or override_reason is not null);

-- =====================================================================
-- F-3: PIN columns are writable only by PIN RPCs (GUC) or admins
--   TRIGGER chosen over column GRANTs because column grants apply to the
--   shared `authenticated` role and would break admin verification PATCH
--   and advocate onboarding (nid_number, bar_council_no, sanad_url, ...).
--   INSERT branch: counters cannot be planted at row creation either.
--   Soft-delete doctrine (§5.1): DELETE never granted to application roles.
-- =====================================================================
revoke delete on advocates from authenticated;
revoke delete on profiles from authenticated;   -- no-DELETE doctrine (§5.1), belt & braces

create or replace function advocates_pin_guard() returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('app.internal_write', true), '') = '1'
     or (select public.is_admin()) then
    return new;                      -- trusted path
  end if;

  if tg_op = 'INSERT' then
    if new.pin_fail_count <> 0 or new.pin_locked_until is not null then
      raise exception 'pin_guard: pin counters cannot be set on insert';
    end if;
    return new;
  end if;

  if new.pin_hash is distinct from old.pin_hash
     or new.pin_fail_count is distinct from old.pin_fail_count
     or new.pin_locked_until is distinct from old.pin_locked_until then
    raise exception 'pin_guard: pin fields are writable only via PIN RPCs';
  end if;
  return new;
end;
$$;

drop trigger if exists advocates_pin_guard on advocates;
create trigger advocates_pin_guard
  before insert or update on advocates
  for each row execute function advocates_pin_guard();

-- (No UPDATE revoke on advocates: profile edits by the advocate and admin
--  PATCH for verification must keep working — PIN columns are the entire
--  attack surface and are guarded above. DELETE is revoked per doctrine.)
